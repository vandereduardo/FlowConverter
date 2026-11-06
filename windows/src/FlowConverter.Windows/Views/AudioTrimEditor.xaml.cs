using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Rectangle = System.Windows.Shapes.Rectangle;
using FlowConverter.Windows.Engines;
using FlowConverter.Windows.Models;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Views;

public partial class AudioTrimEditor : UserControl
{
    private const double HandleWidth = 14;
    private const double HandleInset = HandleWidth / 2;
    private static readonly Brush SelectionBrush = ThemeBrushes.Get("ThemeAccent");
    private static readonly Brush Shade = ThemeBrushes.Get("ThemeWaveformShade");
    private static readonly Brush WaveBrush = new LinearGradientBrush(
        ThemeBrushes.Get("ThemeAccent").Color, ThemeBrushes.Get("ThemeWarmAccent").Color, 90);

    private enum DragTarget { None, Start, End, Range }

    private readonly string _source;
    private readonly int _fileCount;
    private readonly FileToolExecutionOptions _options;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly MediaPlayer _player = new();
    private CancellationTokenSource? _preview;
    private string? _previewFile;
    private double _duration;
    private double[] _peaks = Array.Empty<double>();
    private DragTarget _drag;
    private double _dragOrigin;
    private double _dragStart;
    private double _dragEnd;

    public event Action? Ready;

    internal AudioTrimEditor(string source, int fileCount, FileToolExecutionOptions options)
    {
        _source = source;
        _fileCount = fileCount;
        _options = options;
        InitializeComponent();
        ThresholdLabel.Text = UiText.Format("Silence threshold: {0:0} dB", Threshold.Value);
        Loaded += async (_, _) => await LoadWaveformAsync();
        Unloaded += (_, _) =>
        {
            _lifetime.Cancel();
            StopPreview();
            _lifetime.Dispose();
        };
        _player.MediaEnded += (_, _) => StopPreview();
        _player.MediaFailed += (_, _) =>
        {
            StopPreview();
            Status.Text = UiText.Get("Could not play the preview audio.");
        };
    }

    private async Task LoadWaveformAsync()
    {
        if (UniversalConversionEngine.FindExecutable("ffmpeg.exe") == null)
        {
            Status.Text = UiText.Get("Set up FFmpeg to load the waveform and trim this audio.");
            SetupButton.Content = UiText.Get("Set up FFmpeg…");
            SetupButton.Visibility = Visibility.Visible;
            return;
        }

        SetupButton.Visibility = Visibility.Collapsed;
        Status.Text = UiText.Get("Reading audio waveform…");
        var token = _lifetime.Token;
        try
        {
            var analysis = await AudioTrimEngine.ReadWaveformAsync(_source, token);
            token.ThrowIfCancellationRequested();
            (_duration, _peaks) = analysis;
            Total.Text = $"Total: {TimeLabel(_duration)}";
            Status.Text = _fileCount > 1 ? UiText.Get("Previewing the first file. The selected times apply to all files.") : "";
            DrawWaveform();
            SetRange(0, _duration);
            Editor.IsEnabled = true;
            Ready?.Invoke();
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested) { }
        catch (Exception ex)
        {
            if (!token.IsCancellationRequested)
            {
                Status.Text = UiText.Format("Could not read the audio. {0}", ex.Message);
                SetupButton.Content = UiText.Get("Check FFmpeg…");
                SetupButton.Visibility = Visibility.Visible;
            }
        }
    }

    private async void Setup_Click(object sender, RoutedEventArgs e)
    {
        SetupButton.IsEnabled = false;
        FfmpegSetupWindow.ShowSetup(Window.GetWindow(this), UiText.Get("Trim Audio"));
        await LoadWaveformAsync();
        SetupButton.IsEnabled = true;
    }

    private void SetRange(double start, double end)
    {
        StopPreview();
        _options.TrimStartSeconds = start;
        _options.TrimEndSeconds = end;
        StartTime.Text = TimeLabel(start);
        EndTime.Text = TimeLabel(end);
        SelectedDuration.Text = TimeLabel(end - start);
        DrawSelection();
    }

    private double MinimumRange => Math.Min(0.01, _duration);
    private void SetStart(double time) => SetRange(
        Math.Clamp(time, 0, Math.Max(0, _options.TrimEndSeconds - MinimumRange)), _options.TrimEndSeconds);
    private void SetEnd(double time) => SetRange(_options.TrimStartSeconds,
        Math.Clamp(time, Math.Min(_duration, _options.TrimStartSeconds + MinimumRange), _duration));

    private static string TimeLabel(double seconds)
    {
        var time = TimeSpan.FromSeconds(seconds);
        return $"{(int)time.TotalMinutes:00}:{time.Seconds:00}.{time.Milliseconds / 10:00}";
    }

    private static double Step(object sender) => double.Parse(
        (string)((Button)sender).Tag, CultureInfo.InvariantCulture);

    private void NudgeStart_Click(object sender, RoutedEventArgs e) => SetStart(_options.TrimStartSeconds + Step(sender));
    private void NudgeEnd_Click(object sender, RoutedEventArgs e) => SetEnd(_options.TrimEndSeconds + Step(sender));
    private void Reset_Click(object sender, RoutedEventArgs e) => SetRange(0, _duration);

    private double TrackWidth => Math.Max(0, Timeline.ActualWidth - HandleWidth);
    private double Position(double seconds) => HandleInset + seconds / _duration * TrackWidth;

    private void Timeline_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        DrawWaveform();
        DrawSelection();
    }

    private void DrawWaveform()
    {
        if (_peaks.Length == 0 || TrackWidth <= 0) return;
        Waveform.Children.Clear();
        double spacing = TrackWidth / _peaks.Length;
        for (int i = 0; i < _peaks.Length; i++)
        {
            double height = Math.Max(2, _peaks[i] * Timeline.ActualHeight * 0.84);
            double width = Math.Clamp(spacing - 2, 1, 6);
            AddBar(Waveform, HandleInset + (i + 0.5) * spacing - width / 2,
                (Timeline.ActualHeight - height) / 2, width, height, WaveBrush, 2);
        }
    }

    private void DrawSelection()
    {
        if (_duration <= 0 || TrackWidth <= 0) return;
        Timeline.Children.Clear();
        double left = Position(_options.TrimStartSeconds);
        double right = Position(_options.TrimEndSeconds);
        double height = Timeline.ActualHeight;
        AddBar(Timeline, 0, 0, left, height, Shade);
        AddBar(Timeline, right, 0, Timeline.ActualWidth - right, height, Shade);
        AddBar(Timeline, left, 0, right - left, 2, SelectionBrush);
        AddBar(Timeline, left, height - 2, right - left, 2, SelectionBrush);
        DrawHandle(left, height);
        DrawHandle(right, height);
    }

    private void DrawHandle(double x, double height)
    {
        AddBar(Timeline, x - HandleInset, 0, HandleWidth, height, SelectionBrush, 5);
        AddBar(Timeline, x - 2.5, height / 2 - 11, 1.5, 22, ThemeBrushes.Get("ThemeOnAccent"), 0.75);
        AddBar(Timeline, x + 1, height / 2 - 11, 1.5, 22, ThemeBrushes.Get("ThemeOnAccent"), 0.75);
    }

    private static void AddBar(Canvas canvas, double x, double y, double width, double height, Brush fill, double radius = 0)
    {
        var bar = new Rectangle { Width = width, Height = height, Fill = fill, RadiusX = radius, RadiusY = radius,
            IsHitTestVisible = false };
        Canvas.SetLeft(bar, x);
        Canvas.SetTop(bar, y);
        canvas.Children.Add(bar);
    }

    private DragTarget HitTestRange(double x)
    {
        double left = Position(_options.TrimStartSeconds);
        double right = Position(_options.TrimEndSeconds);
        double leftDistance = Math.Abs(x - left);
        double rightDistance = Math.Abs(x - right);
        if (Math.Min(leftDistance, rightDistance) <= HandleInset + 3)
            return leftDistance <= rightDistance ? DragTarget.Start : DragTarget.End;
        return x > left && x < right ? DragTarget.Range : DragTarget.None;
    }

    private void Timeline_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (_duration <= 0 || TrackWidth <= 0) return;
        _dragOrigin = e.GetPosition(Timeline).X;
        _drag = HitTestRange(_dragOrigin);
        if (_drag == DragTarget.None || !Timeline.CaptureMouse()) return;
        _dragStart = _options.TrimStartSeconds;
        _dragEnd = _options.TrimEndSeconds;
        e.Handled = true;
    }

    private void Timeline_MouseMove(object sender, MouseEventArgs e)
    {
        if (_duration <= 0 || TrackWidth <= 0) return;
        double x = e.GetPosition(Timeline).X;
        var target = Timeline.IsMouseCaptured ? _drag : HitTestRange(x);
        Timeline.Cursor = target switch
        {
            DragTarget.Start or DragTarget.End => Cursors.SizeWE,
            DragTarget.Range => Cursors.SizeAll,
            _ => Cursors.Arrow
        };
        if (!Timeline.IsMouseCaptured) return;

        double delta = (x - _dragOrigin) / TrackWidth * _duration;
        switch (_drag)
        {
            case DragTarget.Start: SetStart(_dragStart + delta); break;
            case DragTarget.End: SetEnd(_dragEnd + delta); break;
            case DragTarget.Range:
                delta = Math.Clamp(delta, -_dragStart, _duration - _dragEnd);
                SetRange(_dragStart + delta, _dragEnd + delta);
                break;
        }
    }

    private void Timeline_MouseUp(object sender, MouseButtonEventArgs e) => Timeline.ReleaseMouseCapture();
    private void Timeline_LostMouseCapture(object sender, MouseEventArgs e) => _drag = DragTarget.None;

    private void TrimSilence_Changed(object sender, RoutedEventArgs e)
    {
        StopPreview();
        _options.AutoTrimSilence = TrimSilence.IsChecked == true;
        SilenceOptions.Visibility = _options.AutoTrimSilence ? Visibility.Visible : Visibility.Collapsed;
    }

    private void Threshold_Changed(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (ThresholdLabel == null) return;
        StopPreview();
        _options.SilenceThresholdDb = e.NewValue;
        ThresholdLabel.Text = UiText.Format("Silence threshold: {0:0} dB", e.NewValue);
    }

    private async void Play_Click(object sender, RoutedEventArgs e)
    {
        if (_preview != null || _previewFile != null)
        {
            StopPreview();
            return;
        }

        using var request = new CancellationTokenSource();
        _preview = request;
        string temp = Path.Combine(Path.GetTempPath(), $"FlowConverter-preview-{Guid.NewGuid():N}.wav");
        PlayButton.Content = UiText.Get("■  Stop Preview");
        Status.Text = UiText.Get("Preparing audio preview…");
        try
        {
            await AudioTrimEngine.TrimAsync(_source, temp, _options.TrimStartSeconds,
                _options.TrimEndSeconds - _options.TrimStartSeconds, _options.AutoTrimSilence,
                _options.SilenceThresholdDb, preview: true, token: request.Token);
            request.Token.ThrowIfCancellationRequested();
            _player.Open(new Uri(temp));
            _previewFile = temp;
            _player.Play();
            Status.Text = UiText.Get("Playing selected range…");
        }
        catch (OperationCanceledException) when (request.IsCancellationRequested) { }
        catch (Exception ex)
        {
            if (ReferenceEquals(_preview, request))
            {
                StopPreview();
                Status.Text = ex.Message;
            }
        }
        finally
        {
            if (ReferenceEquals(_preview, request)) _preview = null;
            if (_previewFile != temp) DeletePreview(temp);
        }
    }

    internal void StopPreview()
    {
        bool wasPreviewing = _preview != null || _previewFile != null;
        _preview?.Cancel();
        _preview = null;
        if (_previewFile is { } file)
        {
            _player.Close();
            _previewFile = null;
            DeletePreview(file);
        }
        if (wasPreviewing)
        {
            PlayButton.Content = UiText.Get("▶  Play Selected Range");
            Status.Text = _fileCount > 1 ? UiText.Get("Previewing the first file. The selected times apply to all files.") : "";
        }
    }

    private static void DeletePreview(string file)
    {
        try { File.Delete(file); }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
