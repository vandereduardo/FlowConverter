#nullable enable
// FlowConverter - Clean-Room 100% MIT Open Source
// Views/WelcomeWindow.xaml.cs - Welcome and Getting Started Cockpit Dialog

using System;
using System.Windows;
using System.Windows.Input;
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

    public WelcomeWindow()
    {
        InitializeComponent();
    }

    private void Header_MouseDown(object sender, MouseButtonEventArgs e)
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

    private void OpenSettings_Click(object sender, RoutedEventArgs e)
    {
        OnOpenSettings?.Invoke();
    }

    private void GetStarted_Click(object sender, RoutedEventArgs e)
    {
        FlowConverterSettings.Instance.HasSeenWelcomeV2 = true;
        FlowConverterSettings.Instance.Save();
        Close();
    }
}
