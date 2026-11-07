// FlowConverter - Clean-Room 100% MIT Open Source
// Models/SettingsModel.cs - Global Application Settings, Persistence, and Modifiers
#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Models;

public enum ConversionFanTheme
{
    Glass,
    Metallic
}

public enum FloatWheelBehavior
{
    AddToExisting,
    CreateNew
}

public enum WheelModifierKey
{
    Alt,
    Shift,
    Control,
    Win
}

public enum QuickActionType
{
    Float,
    Copy,
    Move,
    CopyPath,
    OpenTerminal
}

public static class QuickActionTypeExtensions
{
    public static string DisplayName(this QuickActionType action) => action switch
    {
        QuickActionType.Float => UiText.Get("Float"),
        QuickActionType.Copy => UiText.Get("Copy"),
        QuickActionType.Move => UiText.Get("Move"),
        QuickActionType.CopyPath => UiText.Get("Copy Path"),
        QuickActionType.OpenTerminal => UiText.Get("Open Terminal"),
        _ => action.ToString()
    };

    public static string ShortWheelLabel(this QuickActionType action) => action switch
    {
        QuickActionType.Float => UiText.Get("Float"),
        QuickActionType.Copy => UiText.Get("Copy"),
        QuickActionType.Move => UiText.Get("Move"),
        QuickActionType.CopyPath => UiText.Get("Copy Path"),
        QuickActionType.OpenTerminal => "Terminal",
        _ => action.ToString()
    };

    public static string IconGlyph(this QuickActionType action) => action switch
    {
        QuickActionType.Float => "\uE71B",        // Pin / PinToScreen
        QuickActionType.Copy => "\uE8C8",         // Copy
        QuickActionType.Move => "\uE8DE",         // Move / Folder
        QuickActionType.CopyPath => "\uE71B",     // Link
        QuickActionType.OpenTerminal => "\uE756", // CommandPrompt / Terminal
        _ => "\uE700"
    };

    public static string Description(this QuickActionType action) => action switch
    {
        QuickActionType.Float => UiText.Get("Float file or folder on screen drop shelf"),
        QuickActionType.Copy => UiText.Get("Copy files and folders to destination"),
        QuickActionType.Move => UiText.Get("Move files and folders to chosen destination"),
        QuickActionType.CopyPath => UiText.Get("Copy absolute file and folder paths to clipboard"),
        QuickActionType.OpenTerminal => UiText.Get("Open terminal at selected folder path"),
        _ => action.DisplayName()
    };

    public static string CenterDescription(this QuickActionType action) => action.Description();
}

/// <summary>
/// Singleton configuration store for FlowConverter, persisted at %APPDATA%\FlowConverter\settings.json.
/// </summary>
public class FlowConverterSettings
{
    private static readonly object _syncRoot = new();
    private static FlowConverterSettings? _instance;

    public static FlowConverterSettings Instance
    {
        get
        {
            if (_instance == null)
            {
                lock (_syncRoot)
                {
                    _instance ??= LoadOrCreate();
                }
            }
            return _instance;
        }
    }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ConversionFanTheme Theme { get; set; } = ConversionFanTheme.Glass;

    public bool SoundsAndHapticsEnabled { get; set; } = true;

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public FloatWheelBehavior FloatBehavior { get; set; } = FloatWheelBehavior.AddToExisting;

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public WheelModifierKey ConversionModifier { get; set; } = WheelModifierKey.Alt;

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public WheelModifierKey ToolsModifier { get; set; } = WheelModifierKey.Shift;

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public WheelModifierKey ActionsModifier { get; set; } = WheelModifierKey.Control;

    public string TerminalApplication { get; set; } = "wt.exe";
    public string? FfmpegExecutablePath { get; set; }

    public bool LaunchAtStartup { get; set; } = false;

    public bool HasSeenWelcomeV2 { get; set; } = false;
    public string? AppLanguage { get; set; }

    public string DefaultImageCompressionStrength { get; set; } = "balanced";

    public string DefaultImageCompressionSize { get; set; } = "large";

    public string DefaultVideoCompressionStrength { get; set; } = "balanced";

    public List<Printer3DModel> ConfiguredPrinters3D { get; set; } = Printer3DModel.DefaultCatalog();

    public Dictionary<string, ConversionOptions> FormatProfiles { get; set; } = new();

    public List<string> AuthorizedFolders { get; set; } = new();

    public int UsageCount { get; set; } = 0;

    public static string SettingsFilePath
    {
        get
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            return Path.Combine(appData, "FlowConverter", "settings.json");
        }
    }

    private static JsonSerializerOptions SerializerOptions => new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };

    public void Save()
    {
        lock (_syncRoot)
        {
            try
            {
                string path = SettingsFilePath;
                string? dir = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }

                string json = JsonSerializer.Serialize(this, SerializerOptions);
                File.WriteAllText(path, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[FlowConverterSettings] Failed to save settings: {ex.Message}");
            }
        }
    }

    public static FlowConverterSettings LoadOrCreate()
    {
        lock (_syncRoot)
        {
            try
            {
                string path = SettingsFilePath;
                if (File.Exists(path))
                {
                    string json = File.ReadAllText(path);
                    var settings = JsonSerializer.Deserialize<FlowConverterSettings>(json, SerializerOptions);
                    if (settings != null)
                    {
                        if (settings.ConfiguredPrinters3D == null || settings.ConfiguredPrinters3D.Count == 0)
                        {
                            settings.ConfiguredPrinters3D = Printer3DModel.DefaultCatalog();
                        }
                        return settings;
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[FlowConverterSettings] Failed to load settings: {ex.Message}");
            }

            var fresh = new FlowConverterSettings();
            fresh.Save();
            return fresh;
        }
    }

    public void ResetPrintersToDefault()
    {
        ConfiguredPrinters3D = Printer3DModel.DefaultCatalog();
        Save();
    }

    public List<Printer3DModel> WheelPrinters3D()
    {
        var enabled = ConfiguredPrinters3D.Where(p => p.ShowInWheel).ToList();
        return enabled.Count > 0 ? enabled : ConfiguredPrinters3D.Take(6).ToList();
    }
}
