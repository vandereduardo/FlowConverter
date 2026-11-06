using System.ComponentModel;
using System.Windows;
using FlowConverter.Windows.Engines;
using FlowConverter.Windows.Models;
using FlowConverter.Windows.Services;

namespace FlowConverter.Windows.Views;

public partial class FfmpegSetupWindow : Window
{
    private CancellationTokenSource? _installation;

    private FfmpegSetupWindow(Window? owner, string? operation)
    {
        InitializeComponent();
        if (owner?.IsVisible == true) Owner = owner;
        WindowStartupLocation = Owner == null ? WindowStartupLocation.CenterScreen : WindowStartupLocation.CenterOwner;
        if (operation != null) Heading.Text = $"Set up FFmpeg to use {operation}";
        Loaded += async (_, _) => await ShowDetectedVersionAsync();
    }

    internal static async Task<bool> EnsureAvailableAsync(Window? owner, string operation)
    {
        if (UniversalConversionEngine.FindExecutable("ffmpeg.exe") is { } executable)
        {
            try
            {
                await FfmpegSetupService.GetVersionAsync(executable);
                return true;
            }
            catch
            {
                // Offer setup when the detected executable cannot run.
            }
        }
        return (owner == null || owner.IsVisible) && ShowSetup(owner, operation);
    }

    internal static bool ShowSetup(Window? owner, string? operation = null) =>
        new FfmpegSetupWindow(owner, operation).ShowDialog() == true;

    private async Task ShowDetectedVersionAsync()
    {
        if (UniversalConversionEngine.FindExecutable("ffmpeg.exe") is not { } executable) return;

        InstallButton.IsEnabled = false;
        BrowseButton.IsEnabled = false;
        Status.Text = "Checking FFmpeg…";
        try
        {
            Status.Text = await FfmpegSetupService.GetVersionAsync(executable);
            InstallButton.Visibility = Visibility.Collapsed;
        }
        catch (Exception ex)
        {
            Status.Text = $"The detected FFmpeg could not start. {ex.Message}";
        }
        finally
        {
            InstallButton.IsEnabled = true;
            BrowseButton.IsEnabled = true;
        }
    }

    private async void Install_Click(object sender, RoutedEventArgs e)
    {
        using var cancellation = new CancellationTokenSource();
        _installation = cancellation;
        SetBusy(true);
        Status.Text = "Preparing the FFmpeg download…";
        var progress = new Progress<string>(message => Status.Text = message);
        bool installed = false;
        try
        {
            await FfmpegSetupService.InstallAsync(progress, cancellation.Token);
            SaveExecutablePath(null);
            installed = true;
        }
        catch (OperationCanceledException)
        {
            Status.Text = cancellation.IsCancellationRequested
                ? "Setup canceled. You can try again."
                : "The download timed out. Please try again.";
        }
        catch (Exception ex)
        {
            Status.Text = $"Could not install FFmpeg. {ex.Message}";
        }
        finally
        {
            _installation = null;
            SetBusy(false);
        }

        if (installed) DialogResult = true;
    }

    private async void Browse_Click(object sender, RoutedEventArgs e)
    {
        var picker = new Microsoft.Win32.OpenFileDialog
        {
            Title = "Select ffmpeg.exe",
            Filter = "FFmpeg executable (ffmpeg.exe)|ffmpeg.exe",
            FileName = "ffmpeg.exe"
        };
        if (picker.ShowDialog(this) != true) return;

        SetBusy(true);
        Status.Text = "Checking the selected executable…";
        bool selected = false;
        try
        {
            await FfmpegSetupService.GetVersionAsync(picker.FileName);
            SaveExecutablePath(picker.FileName);
            selected = true;
        }
        catch (Exception ex)
        {
            Status.Text = $"Could not use the selected FFmpeg. {ex.Message}";
        }
        finally
        {
            SetBusy(false);
        }
        if (selected) DialogResult = true;
    }

    private static void SaveExecutablePath(string? path)
    {
        FlowConverterSettings.Instance.FfmpegExecutablePath = path;
        FlowConverterSettings.Instance.Save();
    }

    private void SetBusy(bool busy)
    {
        InstallButton.IsEnabled = !busy;
        BrowseButton.IsEnabled = !busy;
        InstallProgress.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
        CloseButton.Content = _installation != null ? "Cancel download" : "Close";
        CloseButton.IsEnabled = !busy || _installation != null;
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    protected override void OnClosing(CancelEventArgs e)
    {
        if (_installation != null)
        {
            e.Cancel = true;
            _installation.Cancel();
        }
        else if (!CloseButton.IsEnabled)
        {
            e.Cancel = true;
        }
        base.OnClosing(e);
    }
}
