using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Threading;
using FlowConverter.Windows.Models;

namespace FlowConverter.Windows.Interop;

public enum WheelMode
{
    Conversions,
    FileTools,
    FileActions
}

public sealed class DragGestureMonitor
{
    private readonly DispatcherTimer _timer;
    private bool _wasMouseDown;
    private NativeMethods.POINT _mouseDownOrigin;
    private bool _isDragging;
    private bool _prevAltDown;
    private bool _prevShiftDown;
    private bool _prevCtrlDown;
    private bool _prevWinDown;
    private List<string> _cachedDragFiles = new();

    public event Action<WheelMode, Point, IReadOnlyList<string>>? SummonOrToggleWheelRequested;
    public event Action<Point>? DragCursorMoved;
    public event Action? DragReleased;
    public event Action? DismissWheelRequested;

    public DragGestureMonitor()
    {
        _timer = new DispatcherTimer(DispatcherPriority.Input)
        {
            Interval = TimeSpan.FromMilliseconds(25)
        };
        _timer.Tick += OnTimerTick;
    }

    public void Start() => _timer.Start();
    public void Stop() => _timer.Stop();

    public void UpdateActiveDraggedFiles(IEnumerable<string> paths)
    {
        _cachedDragFiles = new List<string>(paths);
    }

    private void OnTimerTick(object? sender, EventArgs e)
    {
        if (!NativeMethods.GetCursorPos(out NativeMethods.POINT pt))
        {
            return;
        }

        Point screenPt = GetDipPoint(pt.X, pt.Y);
        bool leftDown = NativeMethods.IsKeyDown(NativeMethods.VK_LBUTTON);

        if (NativeMethods.IsKeyDown(NativeMethods.VK_ESCAPE))
        {
            DismissWheelRequested?.Invoke();
        }

        if (leftDown && !_wasMouseDown)
        {
            _wasMouseDown = true;
            _mouseDownOrigin = pt;
            _isDragging = false;
        }
        else if (leftDown && _wasMouseDown)
        {
            double dx = pt.X - _mouseDownOrigin.X;
            double dy = pt.Y - _mouseDownOrigin.Y;
            if (!_isDragging && Math.Sqrt(dx * dx + dy * dy) >= 8.0)
            {
                _isDragging = true;
                TryCaptureExplorerSelection();
            }

            if (_isDragging)
            {
                DragCursorMoved?.Invoke(screenPt);
                CheckModifierTriggers(screenPt);
            }
        }
        else if (!leftDown && _wasMouseDown)
        {
            bool wasDragging = _isDragging;
            _wasMouseDown = false;
            _isDragging = false;
            _prevAltDown = false;
            _prevShiftDown = false;
            _prevCtrlDown = false;
            _prevWinDown = false;

            if (wasDragging)
            {
                DragReleased?.Invoke();
            }
        }
    }

    private void CheckModifierTriggers(Point screenPt)
    {
        bool altDown = NativeMethods.IsKeyDown(NativeMethods.VK_MENU);
        bool shiftDown = NativeMethods.IsKeyDown(NativeMethods.VK_SHIFT);
        bool ctrlDown = NativeMethods.IsKeyDown(NativeMethods.VK_CONTROL);
        bool winDown = NativeMethods.IsKeyDown(NativeMethods.VK_LWIN) || NativeMethods.IsKeyDown(NativeMethods.VK_RWIN);

        var settings = FlowConverterSettings.Instance;

        if (IsModifierJustPressed(settings.ConversionModifier, altDown, shiftDown, ctrlDown, winDown))
        {
            SummonOrToggleWheelRequested?.Invoke(WheelMode.Conversions, screenPt, _cachedDragFiles);
        }
        else if (IsModifierJustPressed(settings.ToolsModifier, altDown, shiftDown, ctrlDown, winDown))
        {
            SummonOrToggleWheelRequested?.Invoke(WheelMode.FileTools, screenPt, _cachedDragFiles);
        }
        else if (IsModifierJustPressed(settings.ActionsModifier, altDown, shiftDown, ctrlDown, winDown))
        {
            SummonOrToggleWheelRequested?.Invoke(WheelMode.FileActions, screenPt, _cachedDragFiles);
        }

        _prevAltDown = altDown;
        _prevShiftDown = shiftDown;
        _prevCtrlDown = ctrlDown;
        _prevWinDown = winDown;
    }

    private bool IsModifierJustPressed(WheelModifierKey key, bool alt, bool shift, bool ctrl, bool win)
    {
        return key switch
        {
            WheelModifierKey.Alt => alt && !_prevAltDown,
            WheelModifierKey.Shift => shift && !_prevShiftDown,
            WheelModifierKey.Control => ctrl && !_prevCtrlDown,
            WheelModifierKey.Win => win && !_prevWinDown,
            _ => false
        };
    }

    private void TryCaptureExplorerSelection()
    {
        try
        {
            IntPtr fgHwnd = NativeMethods.GetForegroundWindow();
            Type? shellType = Type.GetTypeFromProgID("Shell.Application");
            if (shellType == null) return;

            dynamic? shell = Activator.CreateInstance(shellType);
            if (shell == null) return;

            var list = new List<string>();
            dynamic windows = shell.Windows();
            int count = (int)windows.Count;
            for (int i = 0; i < count; i++)
            {
                dynamic? win = windows.Item(i);
                if (win == null) continue;
                try
                {
                    long hwndVal = Convert.ToInt64(win.HWND);
                    if (fgHwnd != IntPtr.Zero && hwndVal != fgHwnd.ToInt64())
                    {
                        continue;
                    }

                    dynamic? doc = win.Document;
                    if (doc == null) continue;
                    dynamic? items = doc.SelectedItems();
                    if (items == null) continue;
                    int itemCount = (int)items.Count;
                    for (int j = 0; j < itemCount; j++)
                    {
                        dynamic? item = items.Item(j);
                        string? path = item?.Path as string;
                        if (!string.IsNullOrWhiteSpace(path) && (File.Exists(path) || Directory.Exists(path)))
                        {
                            list.Add(path);
                        }
                    }
                    if (list.Count > 0)
                    {
                        _cachedDragFiles = list;
                        return;
                    }
                }
                catch
                {
                    // Ignore non-Explorer COM windows
                }
            }
        }
        catch
        {
            // Ignore COM automation errors
        }
    }

    public static Point GetDipPoint(int physicalX, int physicalY)
    {
        var mainWin = Application.Current?.MainWindow;
        if (mainWin != null)
        {
            var source = PresentationSource.FromVisual(mainWin);
            if (source?.CompositionTarget != null)
            {
                var matrix = source.CompositionTarget.TransformFromDevice;
                return matrix.Transform(new Point(physicalX, physicalY));
            }
        }
        return new Point(physicalX, physicalY);
    }
}
