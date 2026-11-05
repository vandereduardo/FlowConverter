// FlowConverter - Clean-Room 100% MIT Open Source
// Views/SettingsWindow.xaml.cs - FlowConverter Settings & Preferences Window
#nullable enable

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using FlowConverter.Windows.Models;

// Disambiguate WPF controls from Windows Forms controls
using Button = System.Windows.Controls.Button;
using ComboBox = System.Windows.Controls.ComboBox;
using ComboBoxItem = System.Windows.Controls.ComboBoxItem;
using CheckBox = System.Windows.Controls.CheckBox;
using TextBox = System.Windows.Controls.TextBox;
using TextBlock = System.Windows.Controls.TextBlock;
using Border = System.Windows.Controls.Border;
using Point = System.Windows.Point;

namespace FlowConverter.Windows.Views;

/// <summary>
/// Preset model item wrapper for the preset models ComboBox.
/// </summary>
public class PresetModelItem
{
    public string Name { get; set; } = "";
    public Printer3DModel? Model { get; set; }
    public bool IsCustom => Model == null;
    public override string ToString() => Name;
}

/// <summary>
/// Format badge item for the Format Matrix grid.
/// </summary>
public class FormatBadgeViewModel
{
    public string Name { get; set; } = "";
    public string TargetsText { get; set; } = "";
}

/// <summary>
/// Format category group for the Format Matrix grid.
/// </summary>
public class FormatGroupViewModel
{
    public string Title { get; set; } = "";
    public string Glyph { get; set; } = "";
    public string FormatsCount { get; set; } = "";
    public List<FormatBadgeViewModel> Badges { get; set; } = new();
}

/// <summary>
/// SettingsWindow: Full parity preferences window for FlowConverter on Windows.
/// </summary>
public partial class SettingsWindow : Window
{
    private readonly List<Button> _sidebarButtons = new();
    private readonly ObservableCollection<Printer3DModel> _configuredPrinters = new();
    private readonly ObservableCollection<string> _authorizedFolders = new();
    private bool _isInitializing = true;

    public SettingsWindow()
    {
        InitializeComponent();

        Loaded += OnWindowLoaded;
        Closed += OnWindowClosed;

        InitializeSettings();
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        try
        {
            var helper = new System.Windows.Interop.WindowInteropHelper(this);
            int darkMode = 1;
            DwmSetWindowAttribute(helper.Handle, 20, ref darkMode, sizeof(int));
        }
        catch
        {
            // Fallback gracefully on older OS versions
        }
    }

    [DllImport("dwmapi.dll", PreserveSig = true)]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    private void OnWindowLoaded(object sender, RoutedEventArgs e)
    {
        SetupSidebar();
    }

    private void OnWindowClosed(object? sender, EventArgs e)
    {
        FlowConverterSettings.Instance.Save();
    }

    private void InitializeSettings()
    {
        _isInitializing = true;

        var settings = FlowConverterSettings.Instance;

        // 1. General Tab
        UsageCountTextBlock.Text = $"{settings.UsageCount} Conversions Done";
        ThemeComboBox.SelectedIndex = settings.Theme == ConversionFanTheme.Metallic ? 1 : 0;
        SoundsCheckBox.IsChecked = settings.SoundsAndHapticsEnabled;
        FloatBehaviorComboBox.SelectedIndex = settings.FloatBehavior == FloatWheelBehavior.CreateNew ? 1 : 0;
        TerminalComboBox.Text = string.IsNullOrWhiteSpace(settings.TerminalApplication) ? "wt.exe" : settings.TerminalApplication;
        StartupCheckBox.IsChecked = settings.LaunchAtStartup;

        // 2. 3D Printers Tab
        ManufacturerComboBox.ItemsSource = Printer3DModel.ManufacturerList;
        ManufacturerComboBox.SelectedItem = "Anycubic";
        PopulatePresetModels("Anycubic");
        NozzleComboBox.SelectedIndex = 1; // 0.4 mm
        FirmwareComboBox.SelectedIndex = 0; // klipper

        PrintersItemsControl.ItemsSource = _configuredPrinters;
        ReloadPrintersList();

        // 3. Wheel Shortcuts Tab
        ConversionModifierComboBox.ItemsSource = Enum.GetValues<WheelModifierKey>();
        ConversionModifierComboBox.SelectedItem = settings.ConversionModifier;

        ToolsModifierComboBox.ItemsSource = Enum.GetValues<WheelModifierKey>();
        ToolsModifierComboBox.SelectedItem = settings.ToolsModifier;

        ActionsModifierComboBox.ItemsSource = Enum.GetValues<WheelModifierKey>();
        ActionsModifierComboBox.SelectedItem = settings.ActionsModifier;

        // 4. Conversion Defaults Tab
        LoadConversionDefaults();

        // 5. Compression Tab
        ImageStrengthComboBox.SelectedIndex = string.Equals(settings.DefaultImageCompressionStrength, "strong", StringComparison.OrdinalIgnoreCase) ? 1 : 0;
        ImageSizeComboBox.SelectedIndex = settings.DefaultImageCompressionSize?.ToLowerInvariant() switch
        {
            "medium" => 1,
            "small" => 2,
            _ => 0 // large
        };
        VideoStrengthComboBox.SelectedIndex = string.Equals(settings.DefaultVideoCompressionStrength, "strong", StringComparison.OrdinalIgnoreCase) ? 1 : 0;

        // 6. Folders Tab
        FoldersItemsControl.ItemsSource = _authorizedFolders;
        ReloadFoldersList();

        // 7. Format Matrix Tab
        PopulateFormatMatrix();

        _isInitializing = false;
    }

    #region Sidebar Navigation

    private void SetupSidebar()
    {
        _sidebarButtons.Clear();
        _sidebarButtons.AddRange(new[]
        {
            BtnNavGeneral,
            BtnNavPrinters,
            BtnNavShortcuts,
            BtnNavConversions,
            BtnNavCompression,
            BtnNavFolders,
            BtnNavMatrix
        });

        SelectTab(0);
    }

    private void SidebarTab_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn)
        {
            int index = _sidebarButtons.IndexOf(btn);
            if (index >= 0)
            {
                SelectTab(index);
            }
        }
    }

    public void SelectTab(int index)
    {
        if (index < 0 || index >= _sidebarButtons.Count) return;
        MainTabControl.SelectedIndex = index;

        for (int i = 0; i < _sidebarButtons.Count; i++)
        {
            bool isActive = (i == index);
            var button = _sidebarButtons[i];

            if (button.Template?.FindName("ActiveIndicator", button) is Border indicator)
            {
                indicator.Visibility = isActive ? Visibility.Visible : Visibility.Collapsed;
            }
            if (button.Template?.FindName("ButtonBorder", button) is Border border)
            {
                border.Background = isActive ? new SolidColorBrush(Color.FromRgb(0x18, 0x24, 0x38)) : Brushes.Transparent;
            }
            if (button.Template?.FindName("NavText", button) is TextBlock text)
            {
                text.Foreground = isActive ? new SolidColorBrush(Color.FromRgb(0x00, 0xE5, 0xFF)) : new SolidColorBrush(Color.FromRgb(0x8A, 0x99, 0xB5));
                text.FontWeight = isActive ? FontWeights.SemiBold : FontWeights.Normal;
            }
            if (button.Template?.FindName("NavIcon", button) is TextBlock icon)
            {
                icon.Foreground = isActive ? new SolidColorBrush(Color.FromRgb(0x00, 0xE5, 0xFF)) : new SolidColorBrush(Color.FromRgb(0x8A, 0x99, 0xB5));
            }
        }
    }

    #endregion

    #region Tab 0: General

    private void ThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        FlowConverterSettings.Instance.Theme = ThemeComboBox.SelectedIndex == 1
            ? ConversionFanTheme.Metallic
            : ConversionFanTheme.Glass;
        FlowConverterSettings.Instance.Save();
    }

    private void SoundsCheckBox_Click(object sender, RoutedEventArgs e)
    {
        if (_isInitializing) return;
        FlowConverterSettings.Instance.SoundsAndHapticsEnabled = SoundsCheckBox.IsChecked ?? true;
        FlowConverterSettings.Instance.Save();
    }

    private void FloatBehaviorComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        FlowConverterSettings.Instance.FloatBehavior = FloatBehaviorComboBox.SelectedIndex == 1
            ? FloatWheelBehavior.CreateNew
            : FloatWheelBehavior.AddToExisting;
        FlowConverterSettings.Instance.Save();
    }

    private void TerminalComboBox_LostFocus(object sender, RoutedEventArgs e)
    {
        SaveTerminalApp();
    }

    private void TerminalComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        if (TerminalComboBox.SelectedItem is ComboBoxItem item && item.Content is string text)
        {
            FlowConverterSettings.Instance.TerminalApplication = text.Trim();
            FlowConverterSettings.Instance.Save();
        }
    }

    private void SaveTerminalApp()
    {
        if (_isInitializing) return;
        string text = TerminalComboBox.Text.Trim();
        if (!string.IsNullOrEmpty(text))
        {
            FlowConverterSettings.Instance.TerminalApplication = text;
            FlowConverterSettings.Instance.Save();
        }
    }

    private void StartupCheckBox_Click(object sender, RoutedEventArgs e)
    {
        if (_isInitializing) return;
        bool enable = StartupCheckBox.IsChecked ?? false;
        FlowConverterSettings.Instance.LaunchAtStartup = enable;
        FlowConverterSettings.Instance.Save();
        ConfigureStartupRegistry(enable);
    }

    private void ConfigureStartupRegistry(bool enable)
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true);
            if (key != null)
            {
                if (enable)
                {
                    string? exe = Environment.ProcessPath;
                    if (string.IsNullOrEmpty(exe))
                    {
                        exe = Process.GetCurrentProcess().MainModule?.FileName;
                    }
                    if (!string.IsNullOrEmpty(exe))
                    {
                        key.SetValue("FlowConverter", $"\"{exe}\"");
                    }
                }
                else
                {
                    key.DeleteValue("FlowConverter", false);
                }
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[SettingsWindow] Startup registry update error: {ex.Message}");
        }
    }

    #endregion

    #region Tab 1: 3D Printers (.3MF)

    private void ManufacturerComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        if (ManufacturerComboBox.SelectedItem is string brand)
        {
            PopulatePresetModels(brand);
        }
    }

    private void PopulatePresetModels(string brand)
    {
        PresetModelComboBox.Items.Clear();
        var presets = Printer3DModel.ModelsForBrand(brand);
        foreach (var preset in presets)
        {
            PresetModelComboBox.Items.Add(new PresetModelItem
            {
                Name = $"{preset.Name} ({preset.BedSizeLabel})",
                Model = preset
            });
        }

        PresetModelComboBox.Items.Add(new PresetModelItem
        {
            Name = "(Custom / Enter Manually…)",
            Model = null
        });

        if (presets.Count > 0)
        {
            PresetModelComboBox.SelectedIndex = 0;
        }
        else
        {
            PresetModelComboBox.SelectedIndex = PresetModelComboBox.Items.Count - 1;
        }
    }

    private void PresetModelComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (PresetModelComboBox.SelectedItem is PresetModelItem item)
        {
            if (item.Model is Printer3DModel preset)
            {
                PrinterNameTextBox.Text = preset.Name;
                ShortWheelNameTextBox.Text = preset.ShortWheelName;
                BedWidthTextBox.Text = preset.BedWidthMM.ToString();
                BedDepthTextBox.Text = preset.BedDepthMM.ToString();
                BedHeightTextBox.Text = preset.BedHeightMM.ToString();

                SelectNozzle(preset.NozzleDiameterMM);
                SelectFirmware(preset.GcodeFlavor);
            }
            else
            {
                PrinterNameTextBox.Text = "";
                ShortWheelNameTextBox.Text = "";
            }
        }
    }

    private void SelectNozzle(double diameter)
    {
        string target = $"{diameter:0.1} mm";
        for (int i = 0; i < NozzleComboBox.Items.Count; i++)
        {
            if (NozzleComboBox.Items[i] is ComboBoxItem item && string.Equals(item.Content?.ToString(), target, StringComparison.OrdinalIgnoreCase))
            {
                NozzleComboBox.SelectedIndex = i;
                return;
            }
        }
        NozzleComboBox.SelectedIndex = 1; // 0.4 mm default
    }

    private void SelectFirmware(string flavor)
    {
        for (int i = 0; i < FirmwareComboBox.Items.Count; i++)
        {
            if (FirmwareComboBox.Items[i] is ComboBoxItem item && string.Equals(item.Content?.ToString(), flavor, StringComparison.OrdinalIgnoreCase))
            {
                FirmwareComboBox.SelectedIndex = i;
                return;
            }
        }
        FirmwareComboBox.SelectedIndex = 0; // klipper default
    }

    private void AddPrinter_Click(object sender, RoutedEventArgs e)
    {
        string name = PrinterNameTextBox.Text.Trim();
        if (string.IsNullOrEmpty(name))
        {
            PrinterNameTextBox.Focus();
            return;
        }

        string brand = ManufacturerComboBox.SelectedItem as string ?? "Custom";
        string shortName = ShortWheelNameTextBox.Text.Trim();
        if (string.IsNullOrEmpty(shortName))
        {
            shortName = name.Length > 12 ? name.Substring(0, 12) : name;
        }

        int width = int.TryParse(BedWidthTextBox.Text.Trim(), out int w) ? Math.Max(50, w) : 256;
        int depth = int.TryParse(BedDepthTextBox.Text.Trim(), out int d) ? Math.Max(50, d) : 256;
        int height = int.TryParse(BedHeightTextBox.Text.Trim(), out int h) ? Math.Max(50, h) : 256;

        string nozzleStr = (NozzleComboBox.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "0.4 mm";
        double nozzle = double.TryParse(nozzleStr.Replace(" mm", "").Trim(), NumberStyles.Any, CultureInfo.InvariantCulture, out double nz) ? nz : 0.4;

        string firmware = (FirmwareComboBox.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "klipper";

        var list = FlowConverterSettings.Instance.ConfiguredPrinters3D;
        int existing = list.FindIndex(p => string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase));
        if (existing >= 0)
        {
            var item = list[existing];
            item.Brand = brand;
            item.ShortWheelName = shortName;
            item.BedWidthMM = width;
            item.BedDepthMM = depth;
            item.BedHeightMM = height;
            item.NozzleDiameterMM = nozzle;
            item.GcodeFlavor = firmware;
            item.ShowInWheel = true;
            list.RemoveAt(existing);
            list.Insert(0, item);
        }
        else
        {
            var printer = new Printer3DModel(
                id: Guid.NewGuid().ToString(),
                brand: brand,
                name: name,
                shortWheelName: shortName,
                bedWidthMM: width,
                bedDepthMM: depth,
                bedHeightMM: height,
                nozzleDiameterMM: nozzle,
                gcodeFlavor: firmware,
                printerSettingsID: $"{name} {nozzle:0.1} nozzle",
                showInWheel: true,
                isCustom: true
            );
            list.Insert(0, printer);
        }

        FlowConverterSettings.Instance.Save();
        ReloadPrintersList();
    }

    private void ReloadPrintersList()
    {
        _configuredPrinters.Clear();
        foreach (var printer in FlowConverterSettings.Instance.ConfiguredPrinters3D)
        {
            _configuredPrinters.Add(printer);
        }
        ActivePrintersCountTextBlock.Text = $"{_configuredPrinters.Count(p => p.ShowInWheel)} active on Radial Wheel";
    }

    private void PrinterShowInWheel_Click(object sender, RoutedEventArgs e)
    {
        if (_isInitializing) return;
        FlowConverterSettings.Instance.Save();
        ActivePrintersCountTextBlock.Text = $"{_configuredPrinters.Count(p => p.ShowInWheel)} active on Radial Wheel";
    }

    private void MovePrinterUp_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is Printer3DModel printer)
        {
            var list = FlowConverterSettings.Instance.ConfiguredPrinters3D;
            int idx = list.FindIndex(p => p.Id == printer.Id);
            if (idx > 0)
            {
                var temp = list[idx];
                list[idx] = list[idx - 1];
                list[idx - 1] = temp;
                FlowConverterSettings.Instance.Save();
                ReloadPrintersList();
            }
        }
    }

    private void MovePrinterDown_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is Printer3DModel printer)
        {
            var list = FlowConverterSettings.Instance.ConfiguredPrinters3D;
            int idx = list.FindIndex(p => p.Id == printer.Id);
            if (idx >= 0 && idx < list.Count - 1)
            {
                var temp = list[idx];
                list[idx] = list[idx + 1];
                list[idx + 1] = temp;
                FlowConverterSettings.Instance.Save();
                ReloadPrintersList();
            }
        }
    }

    private void RemovePrinter_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is Printer3DModel printer)
        {
            FlowConverterSettings.Instance.ConfiguredPrinters3D.RemoveAll(p => p.Id == printer.Id);
            FlowConverterSettings.Instance.Save();
            ReloadPrintersList();
        }
    }

    private void RestorePrinters_Click(object sender, RoutedEventArgs e)
    {
        FlowConverterSettings.Instance.ResetPrintersToDefault();
        ReloadPrintersList();
    }

    #endregion

    #region Tab 2: Wheel Shortcuts

    private void ModifierComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;

        if (ConversionModifierComboBox.SelectedItem is WheelModifierKey convMod)
        {
            FlowConverterSettings.Instance.ConversionModifier = convMod;
        }
        if (ToolsModifierComboBox.SelectedItem is WheelModifierKey toolsMod)
        {
            FlowConverterSettings.Instance.ToolsModifier = toolsMod;
        }
        if (ActionsModifierComboBox.SelectedItem is WheelModifierKey actMod)
        {
            FlowConverterSettings.Instance.ActionsModifier = actMod;
        }

        FlowConverterSettings.Instance.Save();
    }

    #endregion

    #region Tab 3: Conversion Defaults

    private ConversionOptions GetDefaultConversionOptions()
    {
        var settings = FlowConverterSettings.Instance;
        if (!settings.FormatProfiles.TryGetValue("default", out var options) || options == null)
        {
            options = new ConversionOptions();
            settings.FormatProfiles["default"] = options;
        }
        return options;
    }

    private void LoadConversionDefaults()
    {
        var options = GetDefaultConversionOptions();

        QualityComboBox.SelectedIndex = (int)options.Quality;
        PreserveMetadataCheckBox.IsChecked = options.PreserveMetadata;

        switch (options.AudioBitrateKbps)
        {
            case 128: AudioBitrateComboBox.SelectedIndex = 0; break;
            case 256: AudioBitrateComboBox.SelectedIndex = 2; break;
            case 320: AudioBitrateComboBox.SelectedIndex = 3; break;
            default: AudioBitrateComboBox.SelectedIndex = 1; break; // 192 kbps
        }

        switch (options.GifFps)
        {
            case 10: GifFpsComboBox.SelectedIndex = 0; break;
            case 24: GifFpsComboBox.SelectedIndex = 2; break;
            case 30: GifFpsComboBox.SelectedIndex = 3; break;
            default: GifFpsComboBox.SelectedIndex = 1; break; // 15 fps
        }

        switch (options.GifWidth)
        {
            case 360: GifWidthComboBox.SelectedIndex = 0; break;
            case 640: GifWidthComboBox.SelectedIndex = 2; break;
            case 720: GifWidthComboBox.SelectedIndex = 3; break;
            default: GifWidthComboBox.SelectedIndex = 1; break; // 480 px
        }
    }

    private void QualityComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        var options = GetDefaultConversionOptions();
        options.Quality = (ConversionQuality)Math.Clamp(QualityComboBox.SelectedIndex, 0, 2);
        FlowConverterSettings.Instance.Save();
    }

    private void PreserveMetadataCheckBox_Click(object sender, RoutedEventArgs e)
    {
        if (_isInitializing) return;
        var options = GetDefaultConversionOptions();
        options.PreserveMetadata = PreserveMetadataCheckBox.IsChecked ?? true;
        FlowConverterSettings.Instance.Save();
    }

    private void AudioBitrateComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        var options = GetDefaultConversionOptions();
        options.AudioBitrateKbps = AudioBitrateComboBox.SelectedIndex switch
        {
            0 => 128,
            2 => 256,
            3 => 320,
            _ => 192
        };
        FlowConverterSettings.Instance.Save();
    }

    private void GifFpsComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        var options = GetDefaultConversionOptions();
        options.GifFps = GifFpsComboBox.SelectedIndex switch
        {
            0 => 10,
            2 => 24,
            3 => 30,
            _ => 15
        };
        FlowConverterSettings.Instance.Save();
    }

    private void GifWidthComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        var options = GetDefaultConversionOptions();
        options.GifWidth = GifWidthComboBox.SelectedIndex switch
        {
            0 => 360,
            2 => 640,
            3 => 720,
            _ => 480
        };
        FlowConverterSettings.Instance.Save();
    }

    private void RestoreConversionDefaults_Click(object sender, RoutedEventArgs e)
    {
        FlowConverterSettings.Instance.FormatProfiles["default"] = new ConversionOptions();
        FlowConverterSettings.Instance.Save();
        _isInitializing = true;
        LoadConversionDefaults();
        _isInitializing = false;
    }

    #endregion

    #region Tab 4: Compression

    private void CompressionOption_Changed(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;

        FlowConverterSettings.Instance.DefaultImageCompressionStrength = ImageStrengthComboBox.SelectedIndex == 1 ? "strong" : "balanced";
        FlowConverterSettings.Instance.DefaultImageCompressionSize = ImageSizeComboBox.SelectedIndex switch
        {
            1 => "medium",
            2 => "small",
            _ => "large"
        };
        FlowConverterSettings.Instance.DefaultVideoCompressionStrength = VideoStrengthComboBox.SelectedIndex == 1 ? "strong" : "balanced";

        FlowConverterSettings.Instance.Save();
    }

    #endregion

    #region Tab 5: Folders

    private void ReloadFoldersList()
    {
        _authorizedFolders.Clear();
        foreach (var folder in FlowConverterSettings.Instance.AuthorizedFolders)
        {
            _authorizedFolders.Add(folder);
        }
        FoldersEmptyTextBlock.Visibility = _authorizedFolders.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void AddFolder_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new System.Windows.Forms.FolderBrowserDialog();
        dialog.Description = "Select a folder to authorize for FlowConverter";
        dialog.UseDescriptionForTitle = true;
        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK && !string.IsNullOrWhiteSpace(dialog.SelectedPath))
        {
            string path = dialog.SelectedPath.Trim();
            if (!FlowConverterSettings.Instance.AuthorizedFolders.Contains(path, StringComparer.OrdinalIgnoreCase))
            {
                FlowConverterSettings.Instance.AuthorizedFolders.Add(path);
                FlowConverterSettings.Instance.Save();
                ReloadFoldersList();
            }
        }
    }

    private void RemoveFolder_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string path)
        {
            FlowConverterSettings.Instance.AuthorizedFolders.RemoveAll(f => string.Equals(f, path, StringComparison.OrdinalIgnoreCase));
            FlowConverterSettings.Instance.Save();
            ReloadFoldersList();
        }
    }

    #endregion

    #region Tab 6: Format Matrix

    private void PopulateFormatMatrix()
    {
        var groups = new List<FormatGroupViewModel>();
        var allFormats = Enum.GetValues<ConversionFormat>();

        foreach (var group in Enum.GetValues<SupportedFormatGroup>())
        {
            var formatsInGroup = allFormats.Where(f => f.Category() == group).ToList();
            var groupVm = new FormatGroupViewModel
            {
                Title = group.Title(),
                Glyph = group.IconGlyph(),
                FormatsCount = $"{formatsInGroup.Count} formats"
            };

            foreach (var fmt in formatsInGroup)
            {
                int targetsCount = fmt.CompatibleOutputFormats().Count;
                groupVm.Badges.Add(new FormatBadgeViewModel
                {
                    Name = fmt.DisplayName(),
                    TargetsText = $"{targetsCount} targets"
                });
            }

            groups.Add(groupVm);
        }

        FormatMatrixItemsControl.ItemsSource = groups;
    }

    #endregion
}
