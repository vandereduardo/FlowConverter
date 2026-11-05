// FlowConverter - Clean-Room 100% MIT Open Source
// Models/FileToolModels.cs - 29 File Tools, supporting option classes, and interactive models
#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace FlowConverter.Windows.Models;

/// <summary>
/// All 29 file tools available in FlowConverter.
/// </summary>
public enum FileTool
{
    Compress,
    RemoveMetadata,
    EditImage,
    AnnotateImage,
    FrameImage,
    CropImage,
    NormalizeAudio,
    MuteVideo,
    TrimVideo,
    SplitPDF,
    OrganizePDF,
    CreateArchive,
    ExtractArchive,
    CreatePDF,
    MergePDF,
    CropVideo,
    ChangeVideoSpeed,
    JoinVideos,
    VideoSnapshots,
    SplitVideo,
    AudioToVideo,
    TrimAudio,
    AudioChannels,
    CreateCollage,
    ReadQRCode,
    RedactImage,
    RedactVideo,
    RedactAudio,
    Convert3MF
}

public static class FileToolExtensions
{
    public static string DisplayName(this FileTool tool) => tool switch
    {
        FileTool.Compress => "Compress",
        FileTool.RemoveMetadata => "Remove Metadata",
        FileTool.EditImage => "Adjust Image",
        FileTool.AnnotateImage => "Annotate",
        FileTool.FrameImage => "Background",
        FileTool.CropImage => "Crop Image",
        FileTool.NormalizeAudio => "Normalize Volume",
        FileTool.MuteVideo => "Mute Video",
        FileTool.TrimVideo => "Trim Video",
        FileTool.SplitPDF => "Split PDF",
        FileTool.OrganizePDF => "Organize PDF",
        FileTool.CreateArchive => "Create ZIP",
        FileTool.ExtractArchive => "Extract",
        FileTool.CreatePDF => "Create PDF",
        FileTool.MergePDF => "Merge PDF",
        FileTool.CropVideo => "Crop Video",
        FileTool.ChangeVideoSpeed => "Video Speed",
        FileTool.JoinVideos => "Join Videos",
        FileTool.VideoSnapshots => "Snapshots",
        FileTool.SplitVideo => "Split Video",
        FileTool.AudioToVideo => "Audio Visualizer",
        FileTool.TrimAudio => "Trim Audio",
        FileTool.AudioChannels => "Audio Channels",
        FileTool.CreateCollage => "Collage",
        FileTool.ReadQRCode => "Read QR Code",
        FileTool.RedactImage => "Redact Photo",
        FileTool.RedactVideo => "Redact Video",
        FileTool.RedactAudio => "Bleep Audio",
        FileTool.Convert3MF => "3MF Converter",
        _ => tool.ToString()
    };

    public static string ShortWheelLabel(this FileTool tool) => tool switch
    {
        FileTool.Compress => "Compress",
        FileTool.RemoveMetadata => "Metadata",
        FileTool.EditImage => "Adjust",
        FileTool.AnnotateImage => "Annotate",
        FileTool.FrameImage => "Frame",
        FileTool.CropImage => "Crop",
        FileTool.NormalizeAudio => "Normalize",
        FileTool.MuteVideo => "Mute",
        FileTool.TrimVideo => "Trim",
        FileTool.SplitPDF => "Split",
        FileTool.OrganizePDF => "Organize",
        FileTool.CreateArchive => "ZIP",
        FileTool.ExtractArchive => "Extract",
        FileTool.CreatePDF => "Make PDF",
        FileTool.MergePDF => "Merge",
        FileTool.CropVideo => "Crop Video",
        FileTool.ChangeVideoSpeed => "Speed",
        FileTool.JoinVideos => "Join",
        FileTool.VideoSnapshots => "Snapshots",
        FileTool.SplitVideo => "Split Video",
        FileTool.AudioToVideo => "Visualizer",
        FileTool.TrimAudio => "Trim Audio",
        FileTool.AudioChannels => "Channels",
        FileTool.CreateCollage => "Collage",
        FileTool.ReadQRCode => "QR Code",
        FileTool.RedactImage => "Redact",
        FileTool.RedactVideo => "Redact Video",
        FileTool.RedactAudio => "Bleep",
        FileTool.Convert3MF => "Convert 3MF",
        _ => tool.ToString()
    };

    public static string IconGlyph(this FileTool tool) => tool switch
    {
        FileTool.Compress => "\uE7B8",       // ZipFolder / Compress
        FileTool.RemoveMetadata => "\uE74D", // Delete / Clean
        FileTool.EditImage => "\uE790",      // ColorSliders / Adjust
        FileTool.AnnotateImage => "\uE70F",  // Edit / Pen
        FileTool.FrameImage => "\uEB9F",     // PictureFrame / Background
        FileTool.CropImage => "\uE7A8",      // Crop
        FileTool.NormalizeAudio => "\uE995", // Volume3 / Normalize
        FileTool.MuteVideo => "\uE74F",      // Mute
        FileTool.TrimVideo => "\uE7C8",      // Cut / Trim
        FileTool.SplitPDF => "\uE8A5",       // Document split
        FileTool.OrganizePDF => "\uF0E2",    // Tiles / Organize
        FileTool.CreateArchive => "\uF012",  // Package / Archive
        FileTool.ExtractArchive => "\uE8B7", // Open folder / Extract
        FileTool.CreatePDF => "\uEA90",      // PDF Document
        FileTool.MergePDF => "\uEA37",       // Combine documents
        FileTool.CropVideo => "\uE7A8",      // Crop Video
        FileTool.ChangeVideoSpeed => "\uEC48",// Speedometer / Gauge
        FileTool.JoinVideos => "\uE8B2",     // Video reel stack
        FileTool.VideoSnapshots => "\uE722", // Camera snapshot
        FileTool.SplitVideo => "\uE8C6",     // Scissors / Split
        FileTool.AudioToVideo => "\uE8D6",   // Audio waveform visualizer
        FileTool.TrimAudio => "\uE7C8",      // Cut audio
        FileTool.AudioChannels => "\uE7F6",  // Stereo speakers
        FileTool.CreateCollage => "\uE80A",  // Grid / Collage
        FileTool.ReadQRCode => "\uED14",     // QR code
        FileTool.RedactImage => "\uED1A",    // Hide / Redact image
        FileTool.RedactVideo => "\uE7BA",    // Warning / Mask video
        FileTool.RedactAudio => "\uE74F",    // Mute / Bleep audio
        FileTool.Convert3MF => "\uE749",     // 3D Printer / Cube
        _ => "\uE700"
    };

    public static string CenterDescription(this FileTool tool) => tool switch
    {
        FileTool.Compress => "Compress file size while preserving quality",
        FileTool.RemoveMetadata => "Remove EXIF and private metadata tags",
        FileTool.EditImage => "Adjust exposure, brightness, contrast, and color",
        FileTool.AnnotateImage => "Draw arrows, text, shapes, and highlight notes",
        FileTool.FrameImage => "Add gradient background canvas and soft shadows",
        FileTool.CropImage => "Crop image to custom or preset aspect ratio",
        FileTool.NormalizeAudio => "Normalize audio volume to standard broadcast loudness",
        FileTool.MuteVideo => "Remove audio track completely from video",
        FileTool.TrimVideo => "Cut and trim start and end of video",
        FileTool.SplitPDF => "Extract individual pages or ranges from PDF",
        FileTool.OrganizePDF => "Reorder, rotate, or delete PDF pages",
        FileTool.CreateArchive => "Compress files and folders into a ZIP archive",
        FileTool.ExtractArchive => "Extract contents of archive to folder",
        FileTool.CreatePDF => "Combine images or documents into a PDF",
        FileTool.MergePDF => "Merge multiple PDF documents together",
        FileTool.CropVideo => "Crop video frame to custom area",
        FileTool.ChangeVideoSpeed => "Speed up or slow down video playback",
        FileTool.JoinVideos => "Concatenate multiple videos sequentially",
        FileTool.VideoSnapshots => "Capture high-resolution still frames from video",
        FileTool.SplitVideo => "Split video into separate clips or chapters",
        FileTool.AudioToVideo => "Generate video with animated audio waveform",
        FileTool.TrimAudio => "Trim start and end points of audio track",
        FileTool.AudioChannels => "Adjust left/right balance or convert to mono",
        FileTool.CreateCollage => "Combine multiple images into a grid or collage",
        FileTool.ReadQRCode => "Scan and decode QR code from image or PDF",
        FileTool.RedactImage => "Black out or blur sensitive parts of image",
        FileTool.RedactVideo => "Blur or mask sensitive regions in video",
        FileTool.RedactAudio => "Bleep or mute sensitive words in audio",
        FileTool.Convert3MF => "Convert 3MF profile to target 3D printer bed and settings",
        _ => tool.DisplayName()
    };

    public static bool RequiresInteractiveWorkspace(this FileTool tool) => tool switch
    {
        FileTool.EditImage => true,
        FileTool.AnnotateImage => true,
        FileTool.FrameImage => true,
        FileTool.CropImage => true,
        FileTool.CropVideo => true,
        FileTool.TrimVideo => true,
        FileTool.SplitVideo => true,
        FileTool.TrimAudio => true,
        FileTool.CreateCollage => true,
        FileTool.RedactImage => true,
        FileTool.RedactVideo => true,
        FileTool.RedactAudio => true,
        FileTool.OrganizePDF => true,
        FileTool.ReadQRCode => true,
        FileTool.Convert3MF => true,
        FileTool.VideoSnapshots => true,
        _ => false
    };

    public static List<FileTool> CompatibleTools(IReadOnlyList<string> filePaths)
    {
        if (filePaths == null || filePaths.Count == 0)
            return new List<FileTool>();

        bool all3MF = filePaths.All(p => p.EndsWith(".3mf", StringComparison.OrdinalIgnoreCase));
        if (all3MF)
        {
            return new List<FileTool> { FileTool.Convert3MF, FileTool.ExtractArchive, FileTool.CreateArchive };
        }

        var formats = filePaths.Select(ConversionFormatHelper.Detect).ToList();
        bool allDetected = formats.All(f => f.HasValue);
        bool allImages = allDetected && formats.Count > 0 && formats.All(f => f!.Value.Category() == SupportedFormatGroup.Images);
        bool allVideos = allDetected && formats.Count > 0 && formats.All(f => f!.Value.Category() == SupportedFormatGroup.Video && f!.Value != ConversionFormat.Gif);
        bool allAudio = allDetected && formats.Count > 0 && formats.All(f => f!.Value.Category() == SupportedFormatGroup.Audio);
        bool allPDFs = allDetected && formats.Count > 0 && formats.All(f => f!.Value == ConversionFormat.Pdf);
        bool allArchives = allDetected && formats.Count > 0 && formats.All(f => f!.Value.Category() == SupportedFormatGroup.Archives);

        var tools = new List<FileTool>();

        if (allImages)
        {
            tools.AddRange(new[]
            {
                FileTool.Compress,
                FileTool.RemoveMetadata,
                FileTool.CropImage,
                FileTool.EditImage,
                FileTool.AnnotateImage,
                FileTool.FrameImage
            });
            if (filePaths.Count >= 2)
            {
                tools.Add(FileTool.CreateCollage);
            }
            tools.AddRange(new[]
            {
                FileTool.RedactImage,
                FileTool.ReadQRCode,
                FileTool.CreatePDF,
                FileTool.CreateArchive
            });
        }
        else if (allVideos)
        {
            tools.AddRange(new[]
            {
                FileTool.Compress,
                FileTool.RemoveMetadata,
                FileTool.TrimVideo,
                FileTool.SplitVideo,
                FileTool.CropVideo,
                FileTool.ChangeVideoSpeed,
                FileTool.MuteVideo,
                FileTool.VideoSnapshots,
                FileTool.RedactVideo
            });
            if (filePaths.Count >= 2)
            {
                tools.Add(FileTool.JoinVideos);
            }
            tools.Add(FileTool.CreateArchive);
        }
        else if (allAudio)
        {
            tools.AddRange(new[]
            {
                FileTool.TrimAudio,
                FileTool.NormalizeAudio,
                FileTool.AudioChannels,
                FileTool.AudioToVideo,
                FileTool.RedactAudio,
                FileTool.RemoveMetadata,
                FileTool.CreateArchive
            });
        }
        else if (allPDFs)
        {
            tools.AddRange(new[]
            {
                FileTool.Compress,
                FileTool.RemoveMetadata,
                FileTool.OrganizePDF,
                FileTool.SplitPDF,
                FileTool.ReadQRCode
            });
            if (filePaths.Count >= 2)
            {
                tools.Add(FileTool.MergePDF);
            }
            tools.Add(FileTool.CreateArchive);
        }
        else if (allArchives)
        {
            tools.Add(FileTool.ExtractArchive);
            if (filePaths.Count >= 2)
            {
                tools.Add(FileTool.CreateArchive);
            }
        }
        else
        {
            // Mixed files, folders, or document formats can always be bundled into an archive
            tools.Add(FileTool.CreateArchive);
        }

        return tools;
    }
}

// MARK: - Supporting Tool Options & Models

public class CropSelection
{
    public double NormalizedX { get; set; } = 0.05;
    public double NormalizedY { get; set; } = 0.05;
    public double NormalizedWidth { get; set; } = 0.90;
    public double NormalizedHeight { get; set; } = 0.90;

    public CropSelection() { }

    public CropSelection(double x, double y, double width, double height)
    {
        NormalizedX = x;
        NormalizedY = y;
        NormalizedWidth = width;
        NormalizedHeight = height;
    }
}

public enum CropAspectPreset
{
    Free,
    Original,
    Square1x1,
    Landscape16x9,
    Portrait9x16,
    Standard4x3,
    Portrait3x4,
    Photo3x2,
    Portrait2x3
}

public static class CropAspectPresetExtensions
{
    public static double? Ratio(this CropAspectPreset preset, double sourceWidth, double sourceHeight) => preset switch
    {
        CropAspectPreset.Free => null,
        CropAspectPreset.Original => sourceHeight > 0 ? sourceWidth / sourceHeight : 1.0,
        CropAspectPreset.Square1x1 => 1.0,
        CropAspectPreset.Landscape16x9 => 16.0 / 9.0,
        CropAspectPreset.Portrait9x16 => 9.0 / 16.0,
        CropAspectPreset.Standard4x3 => 4.0 / 3.0,
        CropAspectPreset.Portrait3x4 => 3.0 / 4.0,
        CropAspectPreset.Photo3x2 => 3.0 / 2.0,
        CropAspectPreset.Portrait2x3 => 2.0 / 3.0,
        _ => null
    };
}

public enum RedactionStyle
{
    Solid,
    Blur,
    Pixelate
}

public class RedactionRectangle
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public double NormalizedX { get; set; }
    public double NormalizedY { get; set; }
    public double NormalizedW { get; set; }
    public double NormalizedH { get; set; }
    public RedactionStyle Style { get; set; } = RedactionStyle.Solid;
    public double StartTimeSeconds { get; set; } = 0;
    public double EndTimeSeconds { get; set; } = 0;
}

public class RedactionTimeRange
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public double StartSeconds { get; set; }
    public double EndSeconds { get; set; }

    public RedactionTimeRange() { }

    public RedactionTimeRange(double start, double end)
    {
        StartSeconds = start;
        EndSeconds = end;
    }
}

public class ImageAdjustments
{
    public double Exposure { get; set; } = 0;
    public double Brightness { get; set; } = 0;
    public double Contrast { get; set; } = 0;
    public double Saturation { get; set; } = 0;
    public double Highlights { get; set; } = 0;
    public double Shadows { get; set; } = 0;
    public double Temperature { get; set; } = 0;
    public double Tint { get; set; } = 0;
    public double Hue { get; set; } = 0;
    public double Clarity { get; set; } = 0;
    public double Sharpness { get; set; } = 0;
    public double Vignette { get; set; } = 0;
    public double Blur { get; set; } = 0;
}

public class FrameBackgroundPreset
{
    public string Name { get; set; } = "";
    public string StartHex { get; set; } = "#FF5900";
    public string EndHex { get; set; } = "#FFB826";

    public FrameBackgroundPreset() { }

    public FrameBackgroundPreset(string name, string startHex, string endHex)
    {
        Name = name;
        StartHex = startHex;
        EndHex = endHex;
    }

    public static List<FrameBackgroundPreset> AllPresets { get; } = new()
    {
        new FrameBackgroundPreset("Citrus", "#FF5900", "#FFB826"),
        new FrameBackgroundPreset("Mesh", "#6B59F2", "#F266A6"),
        new FrameBackgroundPreset("Meadow", "#33C773", "#BFEB59"),
        new FrameBackgroundPreset("Whisper", "#EBF0FA", "#D6E0F2"),
        new FrameBackgroundPreset("Orchid", "#C759EB", "#7340D9"),
        new FrameBackgroundPreset("Oasis", "#0DAEC0", "#26E0A6"),
        new FrameBackgroundPreset("Lagoon", "#0D73D9", "#1ACCD9"),
        new FrameBackgroundPreset("Aqua", "#33D9F2", "#598CF2"),
        new FrameBackgroundPreset("Dream", "#F299CC", "#A6BFFB"),
        new FrameBackgroundPreset("Sorbet", "#FF738C", "#FFCC66"),
        new FrameBackgroundPreset("Frost", "#D1EBFF", "#F2FAFF"),
        new FrameBackgroundPreset("Emerald", "#0D8C66", "#26CC8C"),
        new FrameBackgroundPreset("Sunset", "#F24059", "#FF9933"),
        new FrameBackgroundPreset("Sky", "#40A6FA", "#99D9FF"),
        new FrameBackgroundPreset("Mint", "#66EBBF", "#33B8A6"),
        new FrameBackgroundPreset("Violet", "#7333C7", "#B366F2"),
        new FrameBackgroundPreset("Graphite", "#383D47", "#1F2129")
    };
}

public class AnnotationItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string ShapeType { get; set; } = "rect"; // "rect", "ellipse", "line", "text", "arrow"
    public double NormalizedX { get; set; }
    public double NormalizedY { get; set; }
    public double NormalizedW { get; set; }
    public double NormalizedH { get; set; }
    public string Text { get; set; } = "";
    public string ColorHex { get; set; } = "#FF6B0D";
    public double StrokeWidth { get; set; } = 2.0;
}

public class FileToolExecutionOptions
{
    // Compress
    public string CompressionPreset { get; set; } = "balanced";
    public double CompressionReductionPercentage { get; set; } = 50.0;
    public int CompressionMaxEdgePixels { get; set; } = 1920;

    // Adjustments
    public ImageAdjustments Adjustments { get; set; } = new();

    // Crop
    public CropSelection CropSelection { get; set; } = new();
    public CropSelection Crop
    {
        get => CropSelection;
        set => CropSelection = value;
    }

    // Trim
    public double TrimStartSeconds { get; set; } = 0;
    public double TrimEndSeconds { get; set; } = 10;

    // Speed
    public double VideoSpeedMultiplier { get; set; } = 1.5;

    // Normalize
    public double TargetLufs { get; set; } = -14.0;

    // Audio Channels
    public bool ForceMono { get; set; } = false;
    public double LeftGain { get; set; } = 1.0;
    public double RightGain { get; set; } = 1.0;

    // Audio Visualizer
    public int ResolutionWidth { get; set; } = 1920;
    public int ResolutionHeight { get; set; } = 1080;
    public int VisualizerWidth
    {
        get => ResolutionWidth;
        set => ResolutionWidth = value;
    }
    public int VisualizerHeight
    {
        get => ResolutionHeight;
        set => ResolutionHeight = value;
    }
    public string AccentColorHex { get; set; } = "#FF6B0D";
    public string? BackgroundImagePath { get; set; }

    // Collage
    public int Columns { get; set; } = 2;
    public int CanvasWidth { get; set; } = 1920;
    public double Spacing { get; set; } = 16;
    public double Padding { get; set; } = 24;
    public double CornerRadius { get; set; } = 12;
    public string BackgroundHex { get; set; } = "#14161D";
    public int CollageColumns { get => Columns; set => Columns = value; }
    public int CollageCanvasWidth { get => CanvasWidth; set => CanvasWidth = value; }
    public int CollageSpacing { get => (int)Spacing; set => Spacing = value; }
    public int CollagePadding { get => (int)Padding; set => Padding = value; }
    public string CollageBackgroundHex { get => BackgroundHex; set => BackgroundHex = value; }

    // Frame
    public FrameBackgroundPreset? Preset { get; set; }
    public FrameBackgroundPreset? FramePreset { get => Preset; set => Preset = value; }
    public int FramePadding { get; set; } = 48;
    public double FrameCornerRadius { get; set; } = 16;
    public double ShadowOpacity { get; set; } = 0.45;

    // Redaction
    public List<RedactionRectangle> Rectangles { get; set; } = new();
    public List<RedactionRectangle> RedactionRectangles { get => Rectangles; set => Rectangles = value; }
    public List<RedactionTimeRange> AudioRanges { get; set; } = new();
    public List<RedactionTimeRange> AudioBleepRanges { get => AudioRanges; set => AudioRanges = value; }
    public RedactionStyle DefaultStyle { get; set; } = RedactionStyle.Solid;
    public RedactionStyle DefaultRedactionStyle { get => DefaultStyle; set => DefaultStyle = value; }

    // Annotations
    public List<AnnotationItem> Items { get; set; } = new();
    public List<AnnotationItem> Annotations { get => Items; set => Items = value; }

    // Snapshots
    public List<double> TimestampsSeconds { get; set; } = new();
    public List<double> SnapshotTimestampsSeconds { get => TimestampsSeconds; set => TimestampsSeconds = value; }

    // Split Video
    public List<double> SplitPointsSeconds { get; set; } = new();

    // Organize PDF
    public List<int> PageOrder { get; set; } = new();
    public Dictionary<int, int> PageRotations { get; set; } = new();

    // 3MF Converter
    public Printer3DModel? TargetPrinter { get; set; }
    public ThreeMFOptimizationPreset OptimizationPreset { get; set; } = ThreeMFOptimizationPreset.KeepOriginal;
    public bool RecenterOnBed { get; set; } = true;
    public bool PreserveFilaments { get; set; } = true;
}
