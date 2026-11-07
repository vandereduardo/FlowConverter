#nullable enable
// FlowConverter - Clean-Room 100% MIT Open Source
// Views/OperationProgressWindow.xaml.cs - Floating Progress HUD Window

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Views;

/// <summary>
/// Interaction logic for OperationProgressWindow.xaml
/// </summary>
public partial class OperationProgressWindow : Window
{
    private readonly string _title;
    private readonly int _totalItems;

    public OperationProgressWindow(string title, int totalItems)
    {
        InitializeComponent();
        _title = string.IsNullOrWhiteSpace(title) ? UiText.Get("Processing…") : title;
        _totalItems = Math.Max(1, totalItems);

        TitleTextBlock.Text = _title;
        ItemsBadgeTextBlock.Text = _totalItems == 1 ? "1 item" : UiText.Format("{0} items", _totalItems);
        StatusTextBlock.Text = UiText.Get("Initializing…");
    }

    public OperationProgressWindow() : this(UiText.Get("Processing…"), 1)
    {
    }

    /// <summary>
    /// Updates the operation progress and status text safely from any thread.
    /// </summary>
    /// <param name="normalizedProgress">Progress from 0.0 to 1.0 (or 0 to 100).</param>
    /// <param name="statusText">Human-readable description of current work.</param>
    public void UpdateProgress(double normalizedProgress, string statusText)
    {
        Dispatcher.InvokeAsync(() =>
        {
            double pct = normalizedProgress > 1.0 ? normalizedProgress : normalizedProgress * 100.0;
            pct = Math.Clamp(pct, 0.0, 100.0);
            MainProgressBar.Value = pct;
            PercentTextBlock.Text = $"{pct:0}%";
            if (!string.IsNullOrWhiteSpace(statusText))
            {
                StatusTextBlock.Text = statusText;
            }
        });
    }

    /// <summary>
    /// Marks the operation finished.
    /// If no errors occurred, reveals the first output file in Explorer and auto-closes after 1.6 seconds.
    /// If errors occurred, displays error message and shows a Close button.
    /// </summary>
    public void Finish(IReadOnlyList<string> outputPaths, IReadOnlyList<string> errors)
    {
        Dispatcher.InvokeAsync(async () =>
        {
            if (errors == null || errors.Count == 0)
            {
                MainProgressBar.Value = 100;
                PercentTextBlock.Text = "100%";
                StatusTextBlock.Foreground = ThemeBrushes.Get("ThemeAccent");
                StatusTextBlock.Text = (outputPaths != null && outputPaths.Count > 0)
                    ? UiText.Format("Complete! {0} file(s) saved.", outputPaths.Count)
                    : UiText.Get("Completed successfully!");

                if (outputPaths != null && outputPaths.Count > 0)
                {
                    string first = outputPaths[0];
                    if (File.Exists(first) || Directory.Exists(first))
                    {
                        try
                        {
                            Process.Start("explorer.exe", $"/select,\"{first}\"");
                        }
                        catch (Exception ex)
                        {
                            Debug.WriteLine($"[OperationProgressWindow] Reveal in Explorer failed: {ex.Message}");
                        }
                    }
                }

                await Task.Delay(1600);
                try
                {
                    Close();
                }
                catch { }
            }
            else
            {
                StatusTextBlock.Foreground = ThemeBrushes.Get("ThemeDanger");
                StatusTextBlock.Text = errors.Count == 1
                    ? UiText.Format("Error: {0}", errors[0])
                    : UiText.Format("Failed with {0} errors: {1}", errors.Count, errors[0]);
                CloseButton.Visibility = Visibility.Visible;
                HeaderCloseButton.Visibility = Visibility.Visible;
            }
        });
    }

    private void Window_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }
}
