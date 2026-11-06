#nullable enable
// FlowConverter - Clean-Room 100% MIT Open Source
// Views/WelcomeWindow.xaml.cs - Welcome and Getting Started Cockpit Dialog

using System;
using System.Windows;
using System.Windows.Input;
using FlowConverter.Windows.Engines;
using FlowConverter.Windows.Models;

namespace FlowConverter.Windows.Views;

/// <summary>
/// Interaction logic for WelcomeWindow.xaml
/// </summary>
public partial class WelcomeWindow : Window
{
    /// <summary>
    /// Optional callback invoked when the user clicks "Open Settings...".
    /// </summary>
    public Action? OnOpenSettings { get; set; }
    public Action? OnOpenMediaSettings { get; set; }
    public Action? OnOpen3MfStudio { get; set; }
    public Action? OnOpenFloatShelf { get; set; }
    public Action? OnSummonWheel { get; set; }

    public WelcomeWindow()
    {
        InitializeComponent();
        Activated += (_, _) => MediaSetupNote.Visibility = UniversalConversionEngine.FindExecutable("ffmpeg.exe") == null
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private void OpenMediaSettings_Click(object sender, RoutedEventArgs e) => OnOpenMediaSettings?.Invoke();

    private void Header_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
    }

    private void OpenSettings_Click(object sender, RoutedEventArgs e)
    {
        OnOpenSettings?.Invoke();
    }

    private void Open3MfStudio_Click(object sender, RoutedEventArgs e)
    {
        OnOpen3MfStudio?.Invoke();
    }

    private void OpenFloatShelf_Click(object sender, RoutedEventArgs e)
    {
        OnOpenFloatShelf?.Invoke();
    }

    private void GetStarted_Click(object sender, RoutedEventArgs e)
    {
        FlowConverterSettings.Instance.HasSeenWelcomeV2 = true;
        FlowConverterSettings.Instance.Save();
        OnSummonWheel?.Invoke();
    }
}
