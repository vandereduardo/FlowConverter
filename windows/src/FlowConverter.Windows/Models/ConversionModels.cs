// FlowConverter - Clean-Room 100% MIT Open Source
// Models/ConversionModels.cs - Supported formats, groups, options, and batch resolution
#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace FlowConverter.Windows.Models;

/// <summary>
/// Broad categories of file types supported by FlowConverter.
/// </summary>
public enum SupportedFormatGroup
{
    Images,
    Documents,
    Spreadsheets,
    Audio,
    Video,
    Archives,
    Subtitles
}

public static class SupportedFormatGroupExtensions
{
    public static string Title(this SupportedFormatGroup group) => group switch
    {
        SupportedFormatGroup.Images => "Images",
        SupportedFormatGroup.Documents => "Documents",
        SupportedFormatGroup.Spreadsheets => "Spreadsheets",
        SupportedFormatGroup.Audio => "Audio",
        SupportedFormatGroup.Video => "Video",
        SupportedFormatGroup.Archives => "Archives",
        SupportedFormatGroup.Subtitles => "Subtitles",
        _ => group.ToString()
    };

    public static string IconGlyph(this SupportedFormatGroup group) => group switch
    {
        SupportedFormatGroup.Images => "\uEB9F",       // Segoe Fluent: Photo / Picture
        SupportedFormatGroup.Documents => "\uE8A5",    // Document
        SupportedFormatGroup.Spreadsheets => "\uF0E3", // Table / Spreadsheet
        SupportedFormatGroup.Audio => "\uE8D6",        // Audio / Waveform
        SupportedFormatGroup.Video => "\uE8B2",        // Film / Video
        SupportedFormatGroup.Archives => "\uF012",     // Archive / Package
        SupportedFormatGroup.Subtitles => "\uE8D2",    // Closed Captions / Subtitles
        _ => "\uE8A5"
    };
}

/// <summary>
/// All 46 supported file formats for conversion.
/// </summary>
public enum ConversionFormat
{
    // Images
    Jpg,
    Png,
    Webp,
    Heic,
    Tiff,
    Svg,
    Avif,
    Bmp,

    // Documents
    Pdf,
    Docx,
    Pages,
    Ppt,
    Pptx,
    Txt,
    Md,
    Rtf,
    Rtfd,
    TextClipping,
    Html,
    Epub,

    // Spreadsheets
    Xlsx,
    Xls,
    Ods,
    Csv,
    Tsv,

    // Audio
    Mp3,
    M4a,
    Wav,
    Flac,
    Ogg,
    Opus,
    Aiff,
    Wma,

    // Video
    Mp4,
    Mov,
    Mkv,
    Webm,
    Avi,
    Wmv,
    Gif,

    // Subtitles
    Srt,
    Vtt,

    // Archives
    Zip,
    Tar,
    Gzip,
    Rar
}

public static class ConversionFormatExtensions
{
    public static string RawValue(this ConversionFormat f) => f switch
    {
        ConversionFormat.Jpg => "jpg",
        ConversionFormat.Png => "png",
        ConversionFormat.Webp => "webp",
        ConversionFormat.Heic => "heic",
        ConversionFormat.Tiff => "tiff",
        ConversionFormat.Svg => "svg",
        ConversionFormat.Avif => "avif",
        ConversionFormat.Bmp => "bmp",
        ConversionFormat.Pdf => "pdf",
        ConversionFormat.Docx => "docx",
        ConversionFormat.Pages => "pages",
        ConversionFormat.Ppt => "ppt",
        ConversionFormat.Pptx => "pptx",
        ConversionFormat.Txt => "txt",
        ConversionFormat.Md => "md",
        ConversionFormat.Rtf => "rtf",
        ConversionFormat.Rtfd => "rtfd",
        ConversionFormat.TextClipping => "textClipping",
        ConversionFormat.Html => "html",
        ConversionFormat.Epub => "epub",
        ConversionFormat.Xlsx => "xlsx",
        ConversionFormat.Xls => "xls",
        ConversionFormat.Ods => "ods",
        ConversionFormat.Csv => "csv",
        ConversionFormat.Tsv => "tsv",
        ConversionFormat.Mp3 => "mp3",
        ConversionFormat.M4a => "m4a",
        ConversionFormat.Wav => "wav",
        ConversionFormat.Flac => "flac",
        ConversionFormat.Ogg => "ogg",
        ConversionFormat.Opus => "opus",
        ConversionFormat.Aiff => "aiff",
        ConversionFormat.Wma => "wma",
        ConversionFormat.Mp4 => "mp4",
        ConversionFormat.Mov => "mov",
        ConversionFormat.Mkv => "mkv",
        ConversionFormat.Webm => "webm",
        ConversionFormat.Avi => "avi",
        ConversionFormat.Wmv => "wmv",
        ConversionFormat.Gif => "gif",
        ConversionFormat.Srt => "srt",
        ConversionFormat.Vtt => "vtt",
        ConversionFormat.Zip => "zip",
        ConversionFormat.Tar => "tar",
        ConversionFormat.Gzip => "gz",
        ConversionFormat.Rar => "rar",
        _ => f.ToString().ToLowerInvariant()
    };

    public static string FileExtension(this ConversionFormat f) => f switch
    {
        ConversionFormat.Gzip => "tar.gz",
        ConversionFormat.TextClipping => "textClipping",
        _ => f.RawValue()
    };

    public static string DisplayName(this ConversionFormat f) => f switch
    {
        ConversionFormat.Jpg => "JPG",
        ConversionFormat.Png => "PNG",
        ConversionFormat.Webp => "WEBP",
        ConversionFormat.Heic => "HEIC",
        ConversionFormat.Tiff => "TIFF",
        ConversionFormat.Svg => "SVG",
        ConversionFormat.Avif => "AVIF",
        ConversionFormat.Bmp => "BMP",
        ConversionFormat.Pdf => "PDF",
        ConversionFormat.Docx => "DOCX",
        ConversionFormat.Pages => "PAGES",
        ConversionFormat.Ppt => "PPT",
        ConversionFormat.Pptx => "PPTX",
        ConversionFormat.Txt => "TXT",
        ConversionFormat.Md => "MD",
        ConversionFormat.Rtf => "RTF",
        ConversionFormat.Rtfd => "RTFD",
        ConversionFormat.TextClipping => "TextClipping",
        ConversionFormat.Html => "HTML",
        ConversionFormat.Epub => "EPUB",
        ConversionFormat.Xlsx => "XLSX",
        ConversionFormat.Xls => "XLS",
        ConversionFormat.Ods => "ODS",
        ConversionFormat.Csv => "CSV",
        ConversionFormat.Tsv => "TSV",
        ConversionFormat.Mp3 => "MP3",
        ConversionFormat.M4a => "M4A",
        ConversionFormat.Wav => "WAV",
        ConversionFormat.Flac => "FLAC",
        ConversionFormat.Ogg => "OGG",
        ConversionFormat.Opus => "OPUS",
        ConversionFormat.Aiff => "AIFF",
        ConversionFormat.Wma => "WMA",
        ConversionFormat.Mp4 => "MP4",
        ConversionFormat.Mov => "MOV",
        ConversionFormat.Mkv => "MKV",
        ConversionFormat.Webm => "WEBM",
        ConversionFormat.Avi => "AVI",
        ConversionFormat.Wmv => "WMV",
        ConversionFormat.Gif => "GIF",
        ConversionFormat.Srt => "SRT",
        ConversionFormat.Vtt => "VTT",
        ConversionFormat.Zip => "ZIP",
        ConversionFormat.Tar => "TAR",
        ConversionFormat.Gzip => "TAR.GZ",
        ConversionFormat.Rar => "RAR",
        _ => f.ToString().ToUpperInvariant()
    };

    public static SupportedFormatGroup Category(this ConversionFormat f) => f switch
    {
        ConversionFormat.Jpg or ConversionFormat.Png or ConversionFormat.Webp or ConversionFormat.Heic or
        ConversionFormat.Tiff or ConversionFormat.Svg or ConversionFormat.Avif or ConversionFormat.Bmp
            => SupportedFormatGroup.Images,

        ConversionFormat.Pdf or ConversionFormat.Docx or ConversionFormat.Pages or ConversionFormat.Ppt or
        ConversionFormat.Pptx or ConversionFormat.Txt or ConversionFormat.Md or ConversionFormat.Rtf or
        ConversionFormat.Rtfd or ConversionFormat.TextClipping or ConversionFormat.Html or ConversionFormat.Epub
            => SupportedFormatGroup.Documents,

        ConversionFormat.Xlsx or ConversionFormat.Xls or ConversionFormat.Ods or ConversionFormat.Csv or ConversionFormat.Tsv
            => SupportedFormatGroup.Spreadsheets,

        ConversionFormat.Mp3 or ConversionFormat.M4a or ConversionFormat.Wav or ConversionFormat.Flac or
        ConversionFormat.Ogg or ConversionFormat.Opus or ConversionFormat.Aiff or ConversionFormat.Wma
            => SupportedFormatGroup.Audio,

        ConversionFormat.Mp4 or ConversionFormat.Mov or ConversionFormat.Mkv or ConversionFormat.Webm or
        ConversionFormat.Avi or ConversionFormat.Wmv or ConversionFormat.Gif
            => SupportedFormatGroup.Video,

        ConversionFormat.Srt or ConversionFormat.Vtt
            => SupportedFormatGroup.Subtitles,

        ConversionFormat.Zip or ConversionFormat.Tar or ConversionFormat.Gzip or ConversionFormat.Rar
            => SupportedFormatGroup.Archives,

        _ => SupportedFormatGroup.Documents
    };

    public static string CenterDescription(this ConversionFormat f) => f switch
    {
        ConversionFormat.Zip => "Pack into ZIP archive",
        ConversionFormat.Tar => "Pack into TAR archive",
        ConversionFormat.Gzip => "Pack into TAR.GZ archive",
        _ => $"Convert to {f.DisplayName()}"
    };

    public static List<ConversionFormat> CompatibleOutputFormats(this ConversionFormat f)
    {
        return f switch
        {
            ConversionFormat.Jpg or ConversionFormat.Png or ConversionFormat.Webp or ConversionFormat.Heic or
            ConversionFormat.Tiff or ConversionFormat.Svg or ConversionFormat.Avif or ConversionFormat.Bmp =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Jpg, ConversionFormat.Png, ConversionFormat.Webp, ConversionFormat.Heic,
                    ConversionFormat.Tiff, ConversionFormat.Avif, ConversionFormat.Bmp, ConversionFormat.Pdf,
                    ConversionFormat.Gif, ConversionFormat.Zip
                }.Where(x => x != f).ToList(),

            ConversionFormat.Gif =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Mp4, ConversionFormat.Mov, ConversionFormat.Webm, ConversionFormat.Webp,
                    ConversionFormat.Png, ConversionFormat.Jpg, ConversionFormat.Pdf, ConversionFormat.Zip
                },

            ConversionFormat.Mp4 or ConversionFormat.Mov or ConversionFormat.Mkv or ConversionFormat.Webm or
            ConversionFormat.Avi or ConversionFormat.Wmv =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Mp4, ConversionFormat.Mov, ConversionFormat.Mkv, ConversionFormat.Webm,
                    ConversionFormat.Avi, ConversionFormat.Wmv, ConversionFormat.Gif, ConversionFormat.Mp3,
                    ConversionFormat.M4a, ConversionFormat.Wav, ConversionFormat.Flac, ConversionFormat.Ogg,
                    ConversionFormat.Opus, ConversionFormat.Aiff, ConversionFormat.Zip
                }.Where(x => x != f).ToList(),

            ConversionFormat.Mp3 or ConversionFormat.M4a or ConversionFormat.Wav or ConversionFormat.Flac or
            ConversionFormat.Ogg or ConversionFormat.Opus or ConversionFormat.Aiff or ConversionFormat.Wma =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Mp3, ConversionFormat.M4a, ConversionFormat.Wav, ConversionFormat.Flac,
                    ConversionFormat.Ogg, ConversionFormat.Opus, ConversionFormat.Aiff, ConversionFormat.Wma,
                    ConversionFormat.Mp4, ConversionFormat.Zip
                }.Where(x => x != f).ToList(),

            ConversionFormat.Pdf =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Docx, ConversionFormat.Pages, ConversionFormat.Pptx, ConversionFormat.Xlsx,
                    ConversionFormat.Epub, ConversionFormat.Txt, ConversionFormat.Md, ConversionFormat.Rtf,
                    ConversionFormat.Html, ConversionFormat.Png, ConversionFormat.Jpg, ConversionFormat.Tiff,
                    ConversionFormat.Webp, ConversionFormat.Zip
                },

            ConversionFormat.Docx or ConversionFormat.Pages or ConversionFormat.Txt or ConversionFormat.Md or
            ConversionFormat.Rtf or ConversionFormat.Rtfd or ConversionFormat.TextClipping or
            ConversionFormat.Html or ConversionFormat.Epub =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Pdf, ConversionFormat.Docx, ConversionFormat.Pages, ConversionFormat.Epub,
                    ConversionFormat.Txt, ConversionFormat.Md, ConversionFormat.Rtf, ConversionFormat.Html,
                    ConversionFormat.Zip
                }.Where(x => x != f).ToList(),

            ConversionFormat.Ppt or ConversionFormat.Pptx =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Pdf, ConversionFormat.Pptx, ConversionFormat.Png, ConversionFormat.Jpg,
                    ConversionFormat.Zip
                }.Where(x => x != f).ToList(),

            ConversionFormat.Xlsx or ConversionFormat.Xls or ConversionFormat.Ods or ConversionFormat.Csv or ConversionFormat.Tsv =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Xlsx, ConversionFormat.Xls, ConversionFormat.Ods, ConversionFormat.Csv,
                    ConversionFormat.Tsv, ConversionFormat.Pdf, ConversionFormat.Zip
                }.Where(x => x != f).ToList(),

            ConversionFormat.Srt or ConversionFormat.Vtt =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Srt, ConversionFormat.Vtt, ConversionFormat.Zip
                }.Where(x => x != f).ToList(),

            ConversionFormat.Zip or ConversionFormat.Tar or ConversionFormat.Gzip or ConversionFormat.Rar =>
                new List<ConversionFormat>
                {
                    ConversionFormat.Zip, ConversionFormat.Tar, ConversionFormat.Gzip
                }.Where(x => x != f).ToList(),

            _ => new List<ConversionFormat> { ConversionFormat.Zip }
        };
    }
}

public static class ConversionFormatHelper
{
    public static ConversionFormat? Detect(string? filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath))
            return null;

        string fileName = Path.GetFileName(filePath).ToLowerInvariant();
        if (fileName.EndsWith(".tar.gz", StringComparison.OrdinalIgnoreCase) ||
            fileName.EndsWith(".tgz", StringComparison.OrdinalIgnoreCase))
        {
            return ConversionFormat.Gzip;
        }

        string ext = Path.GetExtension(filePath).TrimStart('.').ToLowerInvariant();
        if (ext == "gz")
            return ConversionFormat.Gzip;

        return ext switch
        {
            "jpg" or "jpeg" or "jpe" => ConversionFormat.Jpg,
            "png" => ConversionFormat.Png,
            "webp" => ConversionFormat.Webp,
            "heic" or "heif" => ConversionFormat.Heic,
            "tif" or "tiff" => ConversionFormat.Tiff,
            "svg" => ConversionFormat.Svg,
            "avif" => ConversionFormat.Avif,
            "bmp" => ConversionFormat.Bmp,
            "pdf" => ConversionFormat.Pdf,
            "mp3" => ConversionFormat.Mp3,
            "m4a" or "aac" => ConversionFormat.M4a,
            "wav" or "wave" => ConversionFormat.Wav,
            "flac" => ConversionFormat.Flac,
            "ogg" or "oga" => ConversionFormat.Ogg,
            "opus" => ConversionFormat.Opus,
            "aif" or "aiff" => ConversionFormat.Aiff,
            "wma" => ConversionFormat.Wma,
            "mp4" or "m4v" => ConversionFormat.Mp4,
            "mov" or "qt" => ConversionFormat.Mov,
            "mkv" => ConversionFormat.Mkv,
            "webm" => ConversionFormat.Webm,
            "avi" => ConversionFormat.Avi,
            "wmv" => ConversionFormat.Wmv,
            "gif" => ConversionFormat.Gif,
            "docx" => ConversionFormat.Docx,
            "pages" => ConversionFormat.Pages,
            "ppt" => ConversionFormat.Ppt,
            "pptx" => ConversionFormat.Pptx,
            "txt" or "text" => ConversionFormat.Txt,
            "md" or "markdown" => ConversionFormat.Md,
            "rtf" => ConversionFormat.Rtf,
            "rtfd" => ConversionFormat.Rtfd,
            "textclipping" => ConversionFormat.TextClipping,
            "htm" or "html" or "xhtml" => ConversionFormat.Html,
            "epub" => ConversionFormat.Epub,
            "xlsx" => ConversionFormat.Xlsx,
            "xls" => ConversionFormat.Xls,
            "ods" => ConversionFormat.Ods,
            "csv" => ConversionFormat.Csv,
            "tsv" or "tab" => ConversionFormat.Tsv,
            "srt" => ConversionFormat.Srt,
            "vtt" => ConversionFormat.Vtt,
            "zip" => ConversionFormat.Zip,
            "tar" => ConversionFormat.Tar,
            "rar" => ConversionFormat.Rar,
            _ => null
        };
    }

    public static List<ConversionFormat> CommonFormatsForBatch(IEnumerable<string>? filePaths)
    {
        if (filePaths == null)
            return new List<ConversionFormat> { ConversionFormat.Zip, ConversionFormat.Tar, ConversionFormat.Gzip };

        var pathList = filePaths.Where(p => !string.IsNullOrWhiteSpace(p)).ToList();
        if (pathList.Count == 0)
            return new List<ConversionFormat> { ConversionFormat.Zip, ConversionFormat.Tar, ConversionFormat.Gzip };

        // If any path is a folder or unrecognized file, return archive formats
        var detectedFormats = new List<ConversionFormat>();
        foreach (var path in pathList)
        {
            if (Directory.Exists(path))
            {
                return new List<ConversionFormat> { ConversionFormat.Zip, ConversionFormat.Tar, ConversionFormat.Gzip };
            }

            var detected = Detect(path);
            if (detected == null)
            {
                return new List<ConversionFormat> { ConversionFormat.Zip, ConversionFormat.Tar, ConversionFormat.Gzip };
            }

            detectedFormats.Add(detected.Value);
        }

        // Compute intersection of compatible formats
        IEnumerable<ConversionFormat>? common = null;
        foreach (var format in detectedFormats)
        {
            var compat = format.CompatibleOutputFormats();
            if (common == null)
            {
                common = compat;
            }
            else
            {
                common = common.Intersect(compat);
            }
        }

        var result = (common ?? Enumerable.Empty<ConversionFormat>()).Distinct().ToList();
        if (result.Count == 0)
        {
            return new List<ConversionFormat> { ConversionFormat.Zip, ConversionFormat.Tar, ConversionFormat.Gzip };
        }

        return result;
    }
}

public enum ConversionQuality
{
    Compact,
    Balanced,
    High
}

public class ConversionOptions
{
    public ConversionQuality Quality { get; set; } = ConversionQuality.Balanced;
    public bool PreserveMetadata { get; set; } = true;
    public int AudioBitrateKbps { get; set; } = 192;
    public int AudioSampleDepthBits { get; set; } = 16;
    public int VideoMaxHeight { get; set; } = 0; // 0 = original
    public int GifFps { get; set; } = 15;
    public int GifWidth { get; set; } = 480;
    public bool Recenter3MFOnBed { get; set; } = true;
    public bool Preserve3MFFilaments { get; set; } = true;
    public ThreeMFOptimizationPreset OptimizationPreset3MF { get; set; } = ThreeMFOptimizationPreset.KeepOriginal;

    public ConversionOptions Clone()
    {
        return (ConversionOptions)MemberwiseClone();
    }
}
