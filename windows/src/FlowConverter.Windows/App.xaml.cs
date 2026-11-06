using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using FlowConverter.Windows.Engines;
using FlowConverter.Windows.Interop;
using FlowConverter.Windows.Localization;
using FlowConverter.Windows.Models;
using FlowConverter.Windows.Services;
using FlowConverter.Windows.Views;

namespace FlowConverter.Windows;

public partial class App : System.Windows.Application
{
    private TrayIconService? _trayService;
    private DragGestureMonitor? _dragMonitor;
    private RadialWheelWindow? _radialWheel;
    private SettingsWindow? _settingsWindow;
    private WelcomeWindow? _welcomeWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // CLI mode for automated testing & batch scripts
        if (e.Args.Length >= 2 && e.Args[0] == "--inspect-3mf")
        {
            var summary = ThreeMFConverterEngine.Inspect(e.Args[1]);
            Console.WriteLine($"File: {summary.FileName}");
            Console.WriteLine($"OriginalPrinter: {summary.OriginalPrinterName}");
            Console.WriteLine($"Bed: {summary.BedWidthMM}x{summary.BedDepthMM}x{summary.BedHeightMM}");
            Console.WriteLine($"Filaments: {summary.Filaments.Count}");
            Shutdown(0);
            return;
        }
        if (e.Args.Length >= 3 && e.Args[0] == "--convert-3mf")
        {
            string src = e.Args[1];
            string targetQuery = e.Args[2];
            var printer = Printer3DModel.AllPresetModels.FirstOrDefault(p =>
                              p.Name.Contains(targetQuery, StringComparison.OrdinalIgnoreCase))
                          ?? Printer3DModel.DefaultCatalog().First();
            string outFile = ThreeMFConverterEngine.Convert(src, printer);
            Console.WriteLine($"Converted3MF: {outFile}");
            Shutdown(0);
            return;
        }

        // Terminate any older running FlowConverter process so newly launched instance takes over cleanly
        try
        {
            int currentPid = Environment.ProcessId;
            foreach (var proc in Process.GetProcessesByName("FlowConverter"))
            {
                if (proc.Id != currentPid)
                {
                    try { proc.Kill(); proc.WaitForExit(1000); } catch { }
                }
            }
        }
        catch { }

        try
        {
            var settings = FlowConverterSettings.Instance;
            if (!UiText.IsSupported(settings.AppLanguage))
            {
                var picker = new LanguageSelectionWindow();
                if (picker.ShowDialog() != true)
                {
                    Shutdown(0);
                    return;
                }
                settings.AppLanguage = picker.SelectedLanguage;
                settings.Save();
            }
            UiText.Apply(settings.AppLanguage!);
            InitializeApplication(e.Args);
        }
        catch (Exception ex)
        {
            System.Windows.MessageBox.Show(UiText.Format("FlowConverter Startup Error:\n{0}", ex.Message), "Flow Converter", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    private void InitializeApplication(IReadOnlyList<string> launchArguments)
    {

        AssetGenerator.EnsureHighlightSoundWav();
        AssetGenerator.EnsureAppIconIco();
        _ = SoundService.Instance;

        _radialWheel = new RadialWheelWindow();
        _radialWheel.PetalSelected += OnWheelPetalSelected;

        _dragMonitor = new DragGestureMonitor();
        _dragMonitor.SummonOrToggleWheelRequested += OnSummonOrToggleWheel;
        _dragMonitor.DragCursorMoved += pt => _radialWheel?.UpdateCursorScreenPoint(pt);
        _dragMonitor.DragReleased += () => _radialWheel?.CommitHighlightedIfAny();
        _dragMonitor.DismissWheelRequested += () => _radialWheel?.Hide();
        _dragMonitor.Start();

        _trayService = new TrayIconService();
        _trayService.SummonConvertWheelRequested += () => SummonWheelAtCursor(WheelMode.Conversions);
        _trayService.SummonToolsWheelRequested += () => SummonWheelAtCursor(WheelMode.FileTools);
        _trayService.SummonActionsWheelRequested += () => SummonWheelAtCursor(WheelMode.FileActions);
        _trayService.Open3MfStudioRequested += Open3MfStudioDialog;
        _trayService.NewFloatShelfRequested += FloatingShelfWindow.CreateNewEmptyShelf;
        _trayService.OpenWelcomeRequested += ShowWelcomeWindow;
        _trayService.OpenSettingsRequested += ShowSettingsWindow;
        _trayService.QuitRequested += () => Shutdown(0);

        FloatingShelfWindow.ConvertRequested += files =>
        {
            if (NativeMethods.GetCursorPos(out var pt))
            {
                Point dip = DragGestureMonitor.GetDipPoint(pt.X, pt.Y);
                _radialWheel.Summon(WheelMode.Conversions, dip, files);
            }
        };

        var files = launchArguments.Where(File.Exists).Select(Path.GetFullPath).ToList();
        if (files.Count > 0 && NativeMethods.GetCursorPos(out var cursor))
        {
            WheelMode mode = files.All(IsThreeMfProject) ? WheelMode.Conversions : WheelMode.FileTools;
            _radialWheel.Summon(mode, DragGestureMonitor.GetDipPoint(cursor.X, cursor.Y), files);
        }
        else
        {
            ShowWelcomeWindow();
        }
        _trayService.ShowNotification(UiText.Get("Flow Converter Active"), UiText.Get("Hold Alt, Shift, or Ctrl while dragging any file!"));
    }

    private void OnSummonOrToggleWheel(WheelMode mode, Point cursorDip, IReadOnlyList<string> draggedFiles)
    {
        if (_radialWheel == null) return;
        if (_radialWheel.IsVisible && _radialWheel.CurrentMode == mode)
        {
            _radialWheel.Hide();
            return;
        }
        SoundService.Instance.PlayPetalHighlight();
        _radialWheel.Summon(mode, cursorDip, draggedFiles);
    }

    private void SummonWheelAtCursor(WheelMode mode)
    {
        if (_radialWheel == null) return;
        if (NativeMethods.GetCursorPos(out var pt))
        {
            Point dip = DragGestureMonitor.GetDipPoint(pt.X, pt.Y);
            SoundService.Instance.PlayPetalHighlight();
            _radialWheel.Summon(mode, dip, Array.Empty<string>());
        }
    }

    private async void OnWheelPetalSelected(RadialWheelWindow.WheelPetalItem petal, IReadOnlyList<string> activeFiles)
    {
        List<string> files = activeFiles.Where(f => File.Exists(f) || Directory.Exists(f)).ToList();

        // If summoned from tray without dragged files, prompt user to pick files
        if (files.Count == 0 && petal.TargetQuickAction != QuickActionType.Float)
        {
            var ofd = new Microsoft.Win32.OpenFileDialog
            {
                Title = UiText.Format("Select file(s) for {0}", petal.CenterDescription),
                Multiselect = true
            };
            if (petal.TargetPrinter3D != null || petal.TargetTool == FileTool.Convert3MF)
            {
                ofd.Filter = "3MF 3D Print Projects (*.3mf)|*.3mf";
            }
            if (ofd.ShowDialog() == true)
            {
                files = ofd.FileNames.ToList();
            }
            if (files.Count == 0) return;
        }

        if ((petal.TargetPrinter3D != null || petal.TargetTool == FileTool.Convert3MF) &&
            !files.All(IsThreeMfProject))
        {
            System.Windows.MessageBox.Show(UiText.Get("Select a .3mf project to use the 3MF Studio or printer converter."),
                "Flow Converter", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        // 1. Direct 3MF Printer Petal
        if (petal.TargetPrinter3D != null)
        {
            var printer = petal.TargetPrinter3D;
            var progressWin = new OperationProgressWindow($"3MF → {printer.Name}", files.Count);
            progressWin.Show();

            var outs = new List<string>();
            var errs = new List<string>();
            await Task.Run(() =>
            {
                for (int i = 0; i < files.Count; i++)
                {
                    try
                    {
                        progressWin.UpdateProgress((double)i / files.Count, UiText.Format("Converting {0} → {1}", Path.GetFileName(files[i]), printer.Name));
                        outs.Add(ThreeMFConverterEngine.Convert(files[i], printer));
                    }
                    catch (Exception ex)
                    {
                        errs.Add($"{Path.GetFileName(files[i])}: {ex.Message}");
                    }
                }
            });
            FlowConverterSettings.Instance.UsageCount += outs.Count;
            FlowConverterSettings.Instance.Save();
            progressWin.Finish(outs, errs);
            return;
        }

        // 2. Standard Format Conversion Petal
        if (petal.TargetFormat.HasValue)
        {
            var fmt = petal.TargetFormat.Value;
            if (fmt.Category() is SupportedFormatGroup.Audio or SupportedFormatGroup.Video &&
                files.Any(File.Exists) &&
                !await FfmpegSetupWindow.EnsureAvailableAsync(null, UiText.Format("Convert to {0}", fmt.DisplayName())))
                return;

            var progressWin = new OperationProgressWindow(UiText.Format("Convert to {0}", fmt.DisplayName()), files.Count);
            progressWin.Show();

            var outs = new List<string>();
            var errs = new List<string>();
            await Task.Run(() =>
            {
                try
                {
                    outs = UniversalConversionEngine.ConvertBatch(
                        files,
                        fmt,
                        new ConversionOptions(),
                        (p, msg) => progressWin.UpdateProgress(p, msg));
                }
                catch (Exception ex)
                {
                    errs.Add(ex.Message);
                }
            });
            FlowConverterSettings.Instance.UsageCount += outs.Count;
            FlowConverterSettings.Instance.Save();
            progressWin.Finish(outs, errs);
            return;
        }

        // 3. File Tool Petal
        if (petal.TargetTool.HasValue)
        {
            var tool = petal.TargetTool.Value;
            if (tool.RequiresInteractiveWorkspace() || tool == FileTool.Convert3MF)
            {
                var studio = new ToolWorkspaceWindow(tool, files);
                studio.Show();
                studio.Activate();
                return;
            }

            if (ToolExecutionEngine.RequiresFfmpeg(tool, files) &&
                !await FfmpegSetupWindow.EnsureAvailableAsync(null, tool.DisplayName()))
                return;

            var progressWin = new OperationProgressWindow(tool.DisplayName(), files.Count);
            progressWin.Show();

            var outs = new List<string>();
            var errs = new List<string>();
            await Task.Run(() =>
            {
                try
                {
                    outs = ToolExecutionEngine.ExecuteBatch(
                        tool,
                        files,
                        new FileToolExecutionOptions(),
                        (p, msg) => progressWin.UpdateProgress(p, msg));
                }
                catch (Exception ex)
                {
                    errs.Add(ex.Message);
                }
            });
            FlowConverterSettings.Instance.UsageCount += outs.Count;
            FlowConverterSettings.Instance.Save();
            progressWin.Finish(outs, errs);
            return;
        }

        // 4. Quick Action Petal
        if (petal.TargetQuickAction.HasValue)
        {
            ExecuteQuickAction(petal.TargetQuickAction.Value, files);
        }
    }

    private void ExecuteQuickAction(QuickActionType action, IReadOnlyList<string> files)
    {
        switch (action)
        {
            case QuickActionType.Float:
                if (files.Count > 0)
                    FloatingShelfWindow.AddFilesToShelf(files);
                else
                    FloatingShelfWindow.CreateNewEmptyShelf();
                break;

            case QuickActionType.Copy:
            {
                var sc = new StringCollection();
                foreach (string f in files) sc.Add(f);
                System.Windows.Clipboard.SetFileDropList(sc);
                _trayService?.ShowNotification("Flow Converter", UiText.Format("Copied {0} file(s) to clipboard.", files.Count));
                break;
            }

            case QuickActionType.CopyPath:
            {
                System.Windows.Clipboard.SetText(string.Join(Environment.NewLine, files));
                _trayService?.ShowNotification("Flow Converter", UiText.Get("Copied file path(s) to clipboard."));
                break;
            }

            case QuickActionType.Move:
            {
                using var fbd = new System.Windows.Forms.FolderBrowserDialog
                {
                    Description = UiText.Get("Choose destination folder to move files")
                };
                if (fbd.ShowDialog() == System.Windows.Forms.DialogResult.OK && !string.IsNullOrWhiteSpace(fbd.SelectedPath))
                {
                    string lastDest = "";
                    foreach (string f in files)
                    {
                        if (!File.Exists(f)) continue;
                        string baseName = Path.GetFileNameWithoutExtension(f);
                        string ext = Path.GetExtension(f).TrimStart('.');
                        string dest = ThreeMFConverterEngine.UniqueOutputPath(fbd.SelectedPath, baseName, ext);
                        File.Move(f, dest);
                        lastDest = dest;
                    }
                    if (!string.IsNullOrEmpty(lastDest))
                    {
                        Process.Start("explorer.exe", $"/select,\"{lastDest}\"");
                    }
                }
                break;
            }

            case QuickActionType.OpenTerminal:
            {
                string first = files.FirstOrDefault() ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                string dir = Directory.Exists(first) ? first : (Path.GetDirectoryName(first) ?? Environment.CurrentDirectory);
                string term = FlowConverterSettings.Instance.TerminalApplication;
                try
                {
                    if (term.Equals("wt.exe", StringComparison.OrdinalIgnoreCase))
                        Process.Start(new ProcessStartInfo("wt.exe", $"-d \"{dir}\"") { UseShellExecute = true });
                    else
                        Process.Start(new ProcessStartInfo("powershell.exe", $"-NoExit -Command \"Set-Location '{dir}'\"") { UseShellExecute = true });
                }
                catch
                {
                    Process.Start(new ProcessStartInfo("powershell.exe") { WorkingDirectory = dir, UseShellExecute = true });
                }
                break;
            }

            case QuickActionType.Share:
            {
                if (files.Count > 0)
                {
                    Process.Start("explorer.exe", $"/select,\"{files[0]}\"");
                }
                break;
            }
        }
    }

    private void Open3MfStudioDialog()
    {
        var ofd = new Microsoft.Win32.OpenFileDialog
        {
            Title = UiText.Get("Select a .3MF file to inspect and convert"),
            Filter = "3MF 3D Print Projects (*.3mf)|*.3mf",
            Multiselect = true
        };
        if (ofd.ShowDialog() == true && ofd.FileNames.Length > 0)
        {
            if (!ofd.FileNames.All(IsThreeMfProject))
            {
                System.Windows.MessageBox.Show(UiText.Get("Select a .3mf project to open 3MF Studio."),
                    "Flow Converter", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            var studio = new ToolWorkspaceWindow(FileTool.Convert3MF, ofd.FileNames);
            studio.Show();
            studio.Activate();
        }
    }

    private static bool IsThreeMfProject(string path) =>
        File.Exists(path) && Path.GetExtension(path).Equals(".3mf", StringComparison.OrdinalIgnoreCase);

    private void ShowWelcomeWindow()
    {
        if (_welcomeWindow == null || !_welcomeWindow.IsLoaded)
        {
            _welcomeWindow = new WelcomeWindow
            {
                OnOpenSettings = ShowSettingsWindow,
                OnOpenMediaSettings = () =>
                {
                    ShowSettingsWindow();
                    _settingsWindow?.ShowMediaSettings();
                },
                OnOpen3MfStudio = Open3MfStudioDialog,
                OnOpenFloatShelf = FloatingShelfWindow.CreateNewEmptyShelf,
                OnSummonWheel = () => SummonWheelAtCursor(WheelMode.Conversions)
            };
        }
        _welcomeWindow.Show();
        _welcomeWindow.Activate();
    }

    private void ShowSettingsWindow()
    {
        if (_settingsWindow == null || !_settingsWindow.IsLoaded)
        {
            _settingsWindow = new SettingsWindow();
        }
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _dragMonitor?.Stop();
        _trayService?.Dispose();
        base.OnExit(e);
    }
}
