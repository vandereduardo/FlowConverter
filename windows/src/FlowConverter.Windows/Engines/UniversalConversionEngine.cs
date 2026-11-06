using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Formats.Tar;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using FlowConverter.Windows.Models;
using FlowConverter.Windows.Services;

namespace FlowConverter.Windows.Engines;

public static class UniversalConversionEngine
{
    public static List<string> ConvertBatch(
        IReadOnlyList<string> inputPaths,
        ConversionFormat targetFormat,
        ConversionOptions? options = null,
        Action<double, string>? progressCallback = null)
    {
        options ??= new ConversionOptions();
        var outputs = new List<string>();
        if (inputPaths.Count == 0) return outputs;

        // Multi-file or folder drop to an archive packs all inputs into one archive
        if (targetFormat is ConversionFormat.Zip or ConversionFormat.Tar or ConversionFormat.Gzip &&
            (inputPaths.Count > 1 || Directory.Exists(inputPaths[0])))
        {
            progressCallback?.Invoke(0.2, $"Packing {inputPaths.Count} items into {targetFormat.DisplayName()}...");
            string archiveOut = PackItemsToArchive(inputPaths, targetFormat);
            outputs.Add(archiveOut);
            progressCallback?.Invoke(1.0, "Archive created.");
            return outputs;
        }

        for (int i = 0; i < inputPaths.Count; i++)
        {
            string src = inputPaths[i];
            progressCallback?.Invoke((double)i / inputPaths.Count, $"Converting {Path.GetFileName(src)} → {targetFormat.DisplayName()}");
            string outPath = ConvertSingle(src, targetFormat, options);
            outputs.Add(outPath);
        }

        progressCallback?.Invoke(1.0, "Conversion finished.");
        return outputs;
    }

    public static string ConvertSingle(string srcPath, ConversionFormat targetFormat, ConversionOptions? options = null)
    {
        options ??= new ConversionOptions();
        if (Directory.Exists(srcPath))
        {
            return PackItemsToArchive(new[] { srcPath }, targetFormat);
        }

        if (!File.Exists(srcPath))
        {
            throw new FileNotFoundException("Source file not found.", srcPath);
        }

        string dir = Path.GetDirectoryName(srcPath) ?? Environment.CurrentDirectory;
        string baseName = GetBaseNameWithoutCompoundExtension(srcPath);
        string outExt = targetFormat.FileExtension();
        string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, baseName, outExt);

        ConversionFormat? srcFormat = ConversionFormatHelper.Detect(srcPath);
        SupportedFormatGroup targetGroup = targetFormat.Category();

        // 1. Subtitles (.srt <-> .vtt)
        if (targetFormat is ConversionFormat.Srt or ConversionFormat.Vtt)
        {
            ConvertSubtitle(srcPath, outPath, targetFormat);
            return outPath;
        }

        // 2. Archives (.zip, .tar, .tar.gz)
        if (targetGroup == SupportedFormatGroup.Archives)
        {
            if (srcFormat != null && srcFormat.Value.Category() == SupportedFormatGroup.Archives)
            {
                ConvertArchiveToArchive(srcPath, outPath, targetFormat);
                return outPath;
            }
            return PackItemsToArchive(new[] { srcPath }, targetFormat);
        }

        // 3. Spreadsheets & Presentations
        if (targetGroup == SupportedFormatGroup.Spreadsheets ||
            (srcFormat != null && srcFormat.Value.Category() == SupportedFormatGroup.Spreadsheets))
        {
            ConvertSpreadsheetPipeline(srcPath, outPath, targetFormat);
            return outPath;
        }

        // 4. Images & Image <-> PDF
        if (srcFormat != null && srcFormat.Value.Category() == SupportedFormatGroup.Images)
        {
            if (targetFormat == ConversionFormat.Pdf)
            {
                CreatePdfFromImages(new[] { srcPath }, outPath);
                return outPath;
            }
            ConvertImage(srcPath, outPath, targetFormat, options);
            return outPath;
        }

        // 5. Documents (TXT, MD, HTML, RTF, DOCX, EPUB, PDF)
        if (targetGroup == SupportedFormatGroup.Documents &&
            (srcFormat == null || srcFormat.Value.Category() == SupportedFormatGroup.Documents))
        {
            ConvertDocument(srcPath, outPath, targetFormat);
            return outPath;
        }

        // 6. Audio & Video via FFmpeg (or native WAV/AIFF fallback)
        if (targetGroup is SupportedFormatGroup.Audio or SupportedFormatGroup.Video)
        {
            ConvertMediaWithFfmpeg(srcPath, outPath, targetFormat, options);
            return outPath;
        }

        // Fallback for image outputs
        if (targetGroup == SupportedFormatGroup.Images)
        {
            ConvertImage(srcPath, outPath, targetFormat, options);
            return outPath;
        }

        File.Copy(srcPath, outPath, overwrite: true);
        return outPath;
    }

    public static string GetBaseNameWithoutCompoundExtension(string path)
    {
        string name = Path.GetFileName(path);
        if (name.EndsWith(".tar.gz", StringComparison.OrdinalIgnoreCase))
            return name[..^7];
        return Path.GetFileNameWithoutExtension(path);
    }

    // ------------------------------------------------------------------------
    // 1. Subtitle Pipeline (.srt <-> .vtt)
    // ------------------------------------------------------------------------
    private static void ConvertSubtitle(string srcPath, string outPath, ConversionFormat targetFormat)
    {
        string content = File.ReadAllText(srcPath, Encoding.UTF8)
            .Replace("\r\n", "\n")
            .Replace('\r', '\n');

        if (targetFormat == ConversionFormat.Vtt)
        {
            var sb = new StringBuilder();
            sb.AppendLine("WEBVTT");
            sb.AppendLine();
            string converted = Regex.Replace(content, @"(\d{2}:\d{2}:\d{2}),(\d{3})", "$1.$2");
            if (converted.StartsWith("WEBVTT", StringComparison.OrdinalIgnoreCase))
            {
                File.WriteAllText(outPath, converted, new UTF8Encoding(false));
                return;
            }
            sb.Append(converted.Trim());
            sb.AppendLine();
            File.WriteAllText(outPath, sb.ToString(), new UTF8Encoding(false));
        }
        else
        {
            string stripped = Regex.Replace(content, @"^WEBVTT[^\n]*\n+", "", RegexOptions.IgnoreCase);
            string converted = Regex.Replace(stripped, @"(\d{2}:\d{2}:\d{2})\.(\d{3})", "$1,$2");
            var blocks = converted.Split("\n\n", StringSplitOptions.RemoveEmptyEntries);
            var sb = new StringBuilder();
            int cue = 1;
            foreach (string block in blocks)
            {
                var lines = block.Trim().Split('\n').ToList();
                if (lines.Count == 0) continue;
                if (!int.TryParse(lines[0].Trim(), out _))
                {
                    sb.AppendLine(cue.ToString(CultureInfo.InvariantCulture));
                }
                foreach (string l in lines)
                    sb.AppendLine(l);
                sb.AppendLine();
                cue++;
            }
            File.WriteAllText(outPath, sb.ToString().TrimEnd() + Environment.NewLine, new UTF8Encoding(false));
        }
    }

    // ------------------------------------------------------------------------
    // 2. Archive Pipeline (.zip, .tar, .tar.gz)
    // ------------------------------------------------------------------------
    public static string PackItemsToArchive(IReadOnlyList<string> inputPaths, ConversionFormat targetFormat)
    {
        string first = inputPaths[0];
        string dir = Path.GetDirectoryName(first) ?? Environment.CurrentDirectory;
        string baseName = inputPaths.Count == 1
            ? GetBaseNameWithoutCompoundExtension(first)
            : "Archive";

        string ext = targetFormat switch
        {
            ConversionFormat.Tar => "tar",
            ConversionFormat.Gzip => "tar.gz",
            _ => "zip"
        };

        string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, baseName, ext);
        string stagingDir = Path.Combine(Path.GetTempPath(), $"flowconverter-pack-{Guid.NewGuid():N}");
        try
        {
            Directory.CreateDirectory(stagingDir);
            foreach (string item in inputPaths)
            {
                if (File.Exists(item))
                {
                    string dest = Path.Combine(stagingDir, Path.GetFileName(item));
                    File.Copy(item, dest, overwrite: true);
                }
                else if (Directory.Exists(item))
                {
                    string destSub = Path.Combine(stagingDir, Path.GetFileName(item));
                    CopyDirectoryRecursive(item, destSub);
                }
            }

            if (targetFormat == ConversionFormat.Zip)
            {
                ZipFile.CreateFromDirectory(stagingDir, outPath, CompressionLevel.Optimal, includeBaseDirectory: false);
            }
            else if (targetFormat == ConversionFormat.Tar)
            {
                TarFile.CreateFromDirectory(stagingDir, outPath, includeBaseDirectory: false);
            }
            else if (targetFormat == ConversionFormat.Gzip)
            {
                using var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write);
                using var gz = new GZipStream(fs, CompressionLevel.Optimal);
                TarFile.CreateFromDirectory(stagingDir, gz, includeBaseDirectory: false);
            }
            return outPath;
        }
        finally
        {
            try { Directory.Delete(stagingDir, recursive: true); } catch { }
        }
    }

    public static void ExtractArchiveToDirectory(string archivePath, string destDir)
    {
        Directory.CreateDirectory(destDir);
        string lower = archivePath.ToLowerInvariant();
        if (lower.EndsWith(".zip") || lower.EndsWith(".3mf"))
        {
            ZipFile.ExtractToDirectory(archivePath, destDir, overwriteFiles: true);
        }
        else if (lower.EndsWith(".tar.gz") || lower.EndsWith(".tgz") || lower.EndsWith(".gz"))
        {
            using var fs = File.OpenRead(archivePath);
            using var gz = new GZipStream(fs, CompressionMode.Decompress);
            TarFile.ExtractToDirectory(gz, destDir, overwriteFiles: true);
        }
        else if (lower.EndsWith(".tar"))
        {
            TarFile.ExtractToDirectory(archivePath, destDir, overwriteFiles: true);
        }
        else
        {
            RunExternalProcess("tar.exe", new[] { "-xf", archivePath, "-C", destDir });
        }
    }

    private static void ConvertArchiveToArchive(string srcArchive, string outArchive, ConversionFormat targetFormat)
    {
        string tempDir = Path.Combine(Path.GetTempPath(), $"flowconverter-arc-{Guid.NewGuid():N}");
        try
        {
            ExtractArchiveToDirectory(srcArchive, tempDir);
            if (targetFormat == ConversionFormat.Zip)
            {
                ZipFile.CreateFromDirectory(tempDir, outArchive, CompressionLevel.Optimal, includeBaseDirectory: false);
            }
            else if (targetFormat == ConversionFormat.Tar)
            {
                TarFile.CreateFromDirectory(tempDir, outArchive, includeBaseDirectory: false);
            }
            else if (targetFormat == ConversionFormat.Gzip)
            {
                using var fs = new FileStream(outArchive, FileMode.Create, FileAccess.Write);
                using var gz = new GZipStream(fs, CompressionLevel.Optimal);
                TarFile.CreateFromDirectory(tempDir, gz, includeBaseDirectory: false);
            }
        }
        finally
        {
            try { Directory.Delete(tempDir, recursive: true); } catch { }
        }
    }

    private static void CopyDirectoryRecursive(string sourceDir, string targetDir)
    {
        Directory.CreateDirectory(targetDir);
        foreach (string file in Directory.GetFiles(sourceDir))
        {
            File.Copy(file, Path.Combine(targetDir, Path.GetFileName(file)), overwrite: true);
        }
        foreach (string sub in Directory.GetDirectories(sourceDir))
        {
            CopyDirectoryRecursive(sub, Path.Combine(targetDir, Path.GetFileName(sub)));
        }
    }

    // ------------------------------------------------------------------------
    // 3. Image & Native PDF Pipeline
    // ------------------------------------------------------------------------
    public static void ConvertImage(string srcPath, string outPath, ConversionFormat targetFormat, ConversionOptions options)
    {
        if (targetFormat == ConversionFormat.Svg)
        {
            byte[] pngBytes;
            using (var bmp = new Bitmap(srcPath))
            using (var ms = new MemoryStream())
            {
                bmp.Save(ms, ImageFormat.Png);
                pngBytes = ms.ToArray();
            }
            using var img = new Bitmap(srcPath);
            string b64 = Convert.ToBase64String(pngBytes);
            string svg = $"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{img.Width}\" height=\"{img.Height}\" viewBox=\"0 0 {img.Width} {img.Height}\">\n" +
                         $"  <image width=\"{img.Width}\" height=\"{img.Height}\" href=\"data:image/png;base64,{b64}\" />\n" +
                         $"</svg>\n";
            File.WriteAllText(outPath, svg, new UTF8Encoding(false));
            return;
        }

        if (targetFormat == ConversionFormat.Webp)
        {
            string? cwebp = FindExecutable("cwebp.exe");
            if (cwebp != null)
            {
                int q = options.Quality switch
                {
                    ConversionQuality.Compact => 65,
                    ConversionQuality.High => 94,
                    _ => 82
                };
                RunExternalProcess(cwebp, new[] { "-q", q.ToString(CultureInfo.InvariantCulture), srcPath, "-o", outPath });
                return;
            }
        }

        string? ffmpeg = FindExecutable("ffmpeg.exe");
        if (targetFormat is ConversionFormat.Webp or ConversionFormat.Avif or ConversionFormat.Heic && ffmpeg != null)
        {
            RunExternalProcess(ffmpeg, new[] { "-y", "-i", srcPath, outPath });
            return;
        }

        using var sourceBmp = new Bitmap(srcPath);
        SaveBitmapWithFormat(sourceBmp, outPath, targetFormat, options.Quality);
    }

    public static void SaveBitmapWithFormat(Bitmap bmp, string outPath, ConversionFormat targetFormat, ConversionQuality quality = ConversionQuality.Balanced)
    {
        if (targetFormat == ConversionFormat.Jpg)
        {
            long jpegQuality = quality switch
            {
                ConversionQuality.Compact => 65L,
                ConversionQuality.High => 95L,
                _ => 84L
            };
            var encoder = ImageCodecInfo.GetImageEncoders().FirstOrDefault(c => c.FormatID == ImageFormat.Jpeg.Guid);
            using var cleanRgb = new Bitmap(bmp.Width, bmp.Height, PixelFormat.Format24bppRgb);
            using (var g = Graphics.FromImage(cleanRgb))
            {
                g.Clear(Color.White);
                g.DrawImage(bmp, 0, 0, bmp.Width, bmp.Height);
            }
            if (encoder != null)
            {
                using var ep = new EncoderParameters(1);
                ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, jpegQuality);
                cleanRgb.Save(outPath, encoder, ep);
            }
            else
            {
                cleanRgb.Save(outPath, ImageFormat.Jpeg);
            }
            return;
        }

        ImageFormat fmt = targetFormat switch
        {
            ConversionFormat.Bmp => ImageFormat.Bmp,
            ConversionFormat.Tiff => ImageFormat.Tiff,
            ConversionFormat.Gif => ImageFormat.Gif,
            _ => ImageFormat.Png
        };
        bmp.Save(outPath, fmt);
    }

    public static void CreatePdfFromImages(IReadOnlyList<string> imagePaths, string outPdfPath)
    {
        var jpegPages = new List<(byte[] JpegBytes, int Width, int Height)>();
        foreach (string imgPath in imagePaths)
        {
            using var src = new Bitmap(imgPath);
            using var rgb = new Bitmap(src.Width, src.Height, PixelFormat.Format24bppRgb);
            using (var g = Graphics.FromImage(rgb))
            {
                g.Clear(Color.White);
                g.DrawImage(src, 0, 0, src.Width, src.Height);
            }
            using var ms = new MemoryStream();
            rgb.Save(ms, ImageFormat.Jpeg);
            jpegPages.Add((ms.ToArray(), rgb.Width, rgb.Height));
        }
        WriteMinimalJpegPdf(jpegPages, outPdfPath);
    }

    private static void WriteMinimalJpegPdf(List<(byte[] JpegBytes, int Width, int Height)> pages, string outPdfPath)
    {
        using var fs = new FileStream(outPdfPath, FileMode.Create, FileAccess.Write);
        var offsets = new Dictionary<int, long>();

        void WriteAscii(string s)
        {
            byte[] b = Encoding.ASCII.GetBytes(s);
            fs.Write(b, 0, b.Length);
        }

        WriteAscii("%PDF-1.4\n");

        int pageCount = pages.Count;
        // Object 1: Catalog, Object 2: Pages
        // Per page i (0..pageCount-1):
        //   pageObj = 3 + i * 3
        //   contentObj = 4 + i * 3
        //   imgObj = 5 + i * 3
        int totalObjects = 2 + pageCount * 3;

        offsets[1] = fs.Position;
        WriteAscii("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");

        var kids = string.Join(" ", Enumerable.Range(0, pageCount).Select(i => $"{3 + i * 3} 0 R"));
        offsets[2] = fs.Position;
        WriteAscii($"2 0 obj\n<< /Type /Pages /Kids [{kids}] /Count {pageCount} >>\nendobj\n");

        for (int i = 0; i < pageCount; i++)
        {
            var (jpegBytes, w, h) = pages[i];
            int pageObj = 3 + i * 3;
            int contentObj = 4 + i * 3;
            int imgObj = 5 + i * 3;

            double pdfW = 595.0;
            double pdfH = Math.Max(200.0, Math.Round(595.0 * h / Math.Max(w, 1), 2));
            string contentStream = string.Create(CultureInfo.InvariantCulture, $"q\n{pdfW:0.##} 0 0 {pdfH:0.##} 0 0 cm\n/Im{i} Do\nQ\n");
            byte[] contentBytes = Encoding.ASCII.GetBytes(contentStream);

            offsets[pageObj] = fs.Position;
            WriteAscii(string.Create(CultureInfo.InvariantCulture,
                $"{pageObj} 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {pdfW:0.##} {pdfH:0.##}] /Contents {contentObj} 0 R /Resources << /XObject << /Im{i} {imgObj} 0 R >> >> >>\nendobj\n"));

            offsets[contentObj] = fs.Position;
            WriteAscii($"{contentObj} 0 obj\n<< /Length {contentBytes.Length} >>\nstream\n");
            fs.Write(contentBytes, 0, contentBytes.Length);
            WriteAscii("\nendstream\nendobj\n");

            offsets[imgObj] = fs.Position;
            WriteAscii($"{imgObj} 0 obj\n<< /Type /XObject /Subtype /Image /Width {w} /Height {h} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length {jpegBytes.Length} >>\nstream\n");
            fs.Write(jpegBytes, 0, jpegBytes.Length);
            WriteAscii("\nendstream\nendobj\n");
        }

        long xrefPos = fs.Position;
        WriteAscii($"xref\n0 {totalObjects + 1}\n0000000000 65535 f \n");
        for (int objId = 1; objId <= totalObjects; objId++)
        {
            WriteAscii($"{offsets[objId]:D10} 00000 n \n");
        }
        WriteAscii($"trailer\n<< /Size {totalObjects + 1} /Root 1 0 R >>\nstartxref\n{xrefPos}\n%%EOF\n");
    }

    // ------------------------------------------------------------------------
    // 4. Spreadsheet Pipeline (.xlsx, .ods, .csv, .tsv, .html, .pdf)
    // ------------------------------------------------------------------------
    private static void ConvertSpreadsheetPipeline(string srcPath, string outPath, ConversionFormat targetFormat)
    {
        List<List<string>> rows = ReadSpreadsheetRows(srcPath);
        switch (targetFormat)
        {
            case ConversionFormat.Csv:
                WriteDelimitedTable(rows, outPath, ',');
                break;
            case ConversionFormat.Tsv:
                WriteDelimitedTable(rows, outPath, '\t');
                break;
            case ConversionFormat.Xlsx:
            case ConversionFormat.Xls:
                WriteOpenXmlXlsx(rows, outPath);
                break;
            case ConversionFormat.Ods:
                WriteOpenDocumentOds(rows, outPath);
                break;
            case ConversionFormat.Html:
                WriteHtmlTable(rows, outPath, Path.GetFileNameWithoutExtension(srcPath));
                break;
            case ConversionFormat.Pdf:
            {
                var lines = rows.Select(r => string.Join("  |  ", r)).ToList();
                WriteTextPdf(lines, outPath, Path.GetFileNameWithoutExtension(srcPath));
                break;
            }
            default:
                WriteDelimitedTable(rows, outPath, ',');
                break;
        }
    }

    private static List<List<string>> ReadSpreadsheetRows(string srcPath)
    {
        string ext = Path.GetExtension(srcPath).ToLowerInvariant();
        if (ext == ".xlsx")
            return ReadOpenXmlXlsx(srcPath);
        if (ext == ".ods")
            return ReadOpenDocumentOds(srcPath);
        char delim = ext == ".tsv" ? '\t' : ',';
        return ReadDelimitedTable(srcPath, delim);
    }

    private static List<List<string>> ReadDelimitedTable(string path, char delimiter)
    {
        var rows = new List<List<string>>();
        foreach (string line in File.ReadLines(path, Encoding.UTF8))
        {
            var fields = new List<string>();
            var sb = new StringBuilder();
            bool inQuotes = false;
            for (int i = 0; i < line.Length; i++)
            {
                char c = line[i];
                if (c == '"')
                {
                    if (inQuotes && i + 1 < line.Length && line[i + 1] == '"')
                    {
                        sb.Append('"');
                        i++;
                    }
                    else
                    {
                        inQuotes = !inQuotes;
                    }
                }
                else if (c == delimiter && !inQuotes)
                {
                    fields.Add(sb.ToString());
                    sb.Clear();
                }
                else
                {
                    sb.Append(c);
                }
            }
            fields.Add(sb.ToString());
            rows.Add(fields);
        }
        return rows;
    }

    private static void WriteDelimitedTable(List<List<string>> rows, string outPath, char delimiter)
    {
        using var sw = new StreamWriter(outPath, false, new UTF8Encoding(false));
        foreach (var row in rows)
        {
            var escaped = row.Select(cell =>
            {
                if (cell.Contains(delimiter) || cell.Contains('"') || cell.Contains('\n') || cell.Contains('\r'))
                    return $"\"{cell.Replace("\"", "\"\"")}\"";
                return cell;
            });
            sw.WriteLine(string.Join(delimiter, escaped));
        }
    }

    private static List<List<string>> ReadOpenXmlXlsx(string xlsxPath)
    {
        var rows = new List<List<string>>();
        using var archive = ZipFile.OpenRead(xlsxPath);
        var sharedStrings = new List<string>();

        var ssEntry = archive.GetEntry("xl/sharedStrings.xml");
        if (ssEntry != null)
        {
            using var s = ssEntry.Open();
            var doc = XDocument.Load(s);
            foreach (var si in doc.Descendants().Where(e => e.Name.LocalName == "si"))
            {
                sharedStrings.Add(string.Concat(si.Descendants().Where(e => e.Name.LocalName == "t").Select(e => e.Value)));
            }
        }

        var sheetEntry = archive.Entries.FirstOrDefault(e => e.FullName.StartsWith("xl/worksheets/sheet", StringComparison.OrdinalIgnoreCase) && e.FullName.EndsWith(".xml", StringComparison.OrdinalIgnoreCase));
        if (sheetEntry == null) return rows;

        using var sheetStream = sheetEntry.Open();
        var sheetDoc = XDocument.Load(sheetStream);
        foreach (var rEl in sheetDoc.Descendants().Where(e => e.Name.LocalName == "row"))
        {
            var rowVals = new List<string>();
            foreach (var cEl in rEl.Elements().Where(e => e.Name.LocalName == "c"))
            {
                string? tAttr = cEl.Attribute("t")?.Value;
                if (tAttr == "inlineStr")
                {
                    rowVals.Add(string.Concat(cEl.Descendants().Where(e => e.Name.LocalName == "t").Select(e => e.Value)));
                }
                else
                {
                    string vStr = cEl.Elements().FirstOrDefault(e => e.Name.LocalName == "v")?.Value ?? "";
                    if (tAttr == "s" && int.TryParse(vStr, out int ssIdx) && ssIdx >= 0 && ssIdx < sharedStrings.Count)
                        rowVals.Add(sharedStrings[ssIdx]);
                    else
                        rowVals.Add(vStr);
                }
            }
            rows.Add(rowVals);
        }
        return rows;
    }

    private static void WriteOpenXmlXlsx(List<List<string>> rows, string outPath)
    {
        using var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write);
        using var zip = new ZipArchive(fs, ZipArchiveMode.Create);

        WriteZipText(zip, "[Content_Types].xml",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n" +
            "  <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>\n" +
            "  <Default Extension=\"xml\" ContentType=\"application/xml\"/>\n" +
            "  <Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>\n" +
            "  <Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>\n" +
            "</Types>");

        WriteZipText(zip, "_rels/.rels",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
            "  <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>\n" +
            "</Relationships>");

        WriteZipText(zip, "xl/workbook.xml",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n" +
            "  <sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets>\n" +
            "</workbook>");

        WriteZipText(zip, "xl/_rels/workbook.xml.rels",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
            "  <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>\n" +
            "</Relationships>");

        var sb = new StringBuilder();
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        sb.AppendLine("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>");
        for (int r = 0; r < rows.Count; r++)
        {
            sb.Append($"<row r=\"{r + 1}\">");
            for (int c = 0; c < rows[r].Count; c++)
            {
                string escaped = System.Security.SecurityElement.Escape(rows[r][c]) ?? "";
                sb.Append($"<c t=\"inlineStr\"><is><t>{escaped}</t></is></c>");
            }
            sb.AppendLine("</row>");
        }
        sb.AppendLine("</sheetData></worksheet>");
        WriteZipText(zip, "xl/worksheets/sheet1.xml", sb.ToString());
    }

    private static List<List<string>> ReadOpenDocumentOds(string odsPath)
    {
        var rows = new List<List<string>>();
        using var zip = ZipFile.OpenRead(odsPath);
        var entry = zip.GetEntry("content.xml");
        if (entry == null) return rows;
        using var s = entry.Open();
        var doc = XDocument.Load(s);
        foreach (var tr in doc.Descendants().Where(e => e.Name.LocalName == "table-row"))
        {
            var r = new List<string>();
            foreach (var tc in tr.Elements().Where(e => e.Name.LocalName == "table-cell"))
            {
                r.Add(string.Concat(tc.Descendants().Where(e => e.Name.LocalName == "p").Select(e => e.Value)));
            }
            rows.Add(r);
        }
        return rows;
    }

    private static void WriteOpenDocumentOds(List<List<string>> rows, string outPath)
    {
        using var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write);
        using var zip = new ZipArchive(fs, ZipArchiveMode.Create);
        WriteZipText(zip, "mimetype", "application/vnd.oasis.opendocument.spreadsheet");
        WriteZipText(zip, "META-INF/manifest.xml",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<manifest:manifest xmlns:manifest=\"urn:oasis:names:tc:opendocument:xmlns:manifest:1.0\">\n" +
            " <manifest:file-entry manifest:media-type=\"application/vnd.oasis.opendocument.spreadsheet\" manifest:full-path=\"/\"/>\n" +
            " <manifest:file-entry manifest:media-type=\"text/xml\" manifest:full-path=\"content.xml\"/>\n" +
            "</manifest:manifest>");

        var sb = new StringBuilder();
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        sb.AppendLine("<office:document-content xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:table=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\"><office:body><office:spreadsheet><table:table table:name=\"Sheet1\">");
        foreach (var row in rows)
        {
            sb.Append("<table:table-row>");
            foreach (string cell in row)
            {
                string escaped = System.Security.SecurityElement.Escape(cell) ?? "";
                sb.Append($"<table:table-cell><text:p>{escaped}</text:p></table:table-cell>");
            }
            sb.AppendLine("</table:table-row>");
        }
        sb.AppendLine("</table:table></office:spreadsheet></office:body></office:document-content>");
        WriteZipText(zip, "content.xml", sb.ToString());
    }

    private static void WriteHtmlTable(List<List<string>> rows, string outPath, string title)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<!DOCTYPE html><html><head><meta charset=\"utf-8\"/>");
        sb.AppendLine($"<title>{System.Net.WebUtility.HtmlEncode(title)}</title>");
        sb.AppendLine("<style>body{font-family:Segoe UI,sans-serif;background:#0F131D;color:#E8ECF4;padding:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #2A3245;padding:8px 12px;text-align:left}tr:nth-child(even){background:#161C2B}</style></head><body>");
        sb.AppendLine("<table>");
        foreach (var row in rows)
        {
            sb.Append("<tr>");
            foreach (string cell in row)
                sb.Append($"<td>{System.Net.WebUtility.HtmlEncode(cell)}</td>");
            sb.AppendLine("</tr>");
        }
        sb.AppendLine("</table></body></html>");
        File.WriteAllText(outPath, sb.ToString(), new UTF8Encoding(false));
    }

    // ------------------------------------------------------------------------
    // 5. Document Pipeline (TXT, MD, HTML, RTF, DOCX, EPUB, PDF)
    // ------------------------------------------------------------------------
    private static void ConvertDocument(string srcPath, string outPath, ConversionFormat targetFormat)
    {
        string text = ExtractDocumentText(srcPath);
        string title = Path.GetFileNameWithoutExtension(srcPath);

        switch (targetFormat)
        {
            case ConversionFormat.Txt:
            case ConversionFormat.Md:
                File.WriteAllText(outPath, text, new UTF8Encoding(false));
                break;

            case ConversionFormat.Html:
            {
                var paragraphs = text.Replace("\r\n", "\n").Split('\n')
                    .Select(p => $"<p>{System.Net.WebUtility.HtmlEncode(p)}</p>");
                string html = $"<!DOCTYPE html><html><head><meta charset=\"utf-8\"/><title>{System.Net.WebUtility.HtmlEncode(title)}</title></head><body>\n{string.Join("\n", paragraphs)}\n</body></html>";
                File.WriteAllText(outPath, html, new UTF8Encoding(false));
                break;
            }

            case ConversionFormat.Rtf:
            {
                var sb = new StringBuilder();
                sb.Append(@"{\rtf1\ansi\deff0 {\fonttbl {\f0 Segoe UI;}}\f0\fs24 ");
                foreach (string line in text.Replace("\r\n", "\n").Split('\n'))
                {
                    foreach (char c in line)
                    {
                        if (c == '\\' || c == '{' || c == '}')
                            sb.Append('\\').Append(c);
                        else if (c > 127)
                            sb.Append($"\\u{(int)c}?");
                        else
                            sb.Append(c);
                    }
                    sb.Append(@"\par ");
                }
                sb.Append('}');
                File.WriteAllText(outPath, sb.ToString(), Encoding.ASCII);
                break;
            }

            case ConversionFormat.Docx:
                WriteOpenXmlDocx(text, outPath);
                break;

            case ConversionFormat.Epub:
                WriteMinimalEpub(text, title, outPath);
                break;

            case ConversionFormat.Pdf:
            {
                var lines = text.Replace("\r\n", "\n").Split('\n').ToList();
                WriteTextPdf(lines, outPath, title);
                break;
            }

            default:
                File.WriteAllText(outPath, text, new UTF8Encoding(false));
                break;
        }
    }

    public static string ExtractDocumentText(string srcPath)
    {
        string ext = Path.GetExtension(srcPath).ToLowerInvariant();
        if (ext == ".docx")
        {
            try
            {
                using var zip = ZipFile.OpenRead(srcPath);
                var docEntry = zip.GetEntry("word/document.xml");
                if (docEntry != null)
                {
                    using var s = docEntry.Open();
                    var xml = XDocument.Load(s);
                    var paras = xml.Descendants().Where(e => e.Name.LocalName == "p")
                        .Select(p => string.Concat(p.Descendants().Where(e => e.Name.LocalName == "t").Select(e => e.Value)));
                    return string.Join(Environment.NewLine, paras);
                }
            }
            catch { }
        }
        else if (ext is ".pptx" or ".ppt")
        {
            try
            {
                using var zip = ZipFile.OpenRead(srcPath);
                var slides = zip.Entries
                    .Where(e => e.FullName.StartsWith("ppt/slides/slide", StringComparison.OrdinalIgnoreCase) && e.FullName.EndsWith(".xml"))
                    .OrderBy(e => e.FullName)
                    .ToList();
                var sb = new StringBuilder();
                int idx = 1;
                foreach (var slide in slides)
                {
                    using var s = slide.Open();
                    var xml = XDocument.Load(s);
                    var texts = xml.Descendants().Where(e => e.Name.LocalName == "t").Select(e => e.Value);
                    sb.AppendLine($"--- Slide {idx++} ---");
                    sb.AppendLine(string.Join(" ", texts));
                    sb.AppendLine();
                }
                return sb.ToString();
            }
            catch { }
        }
        else if (ext == ".html" || ext == ".htm")
        {
            string raw = File.ReadAllText(srcPath, Encoding.UTF8);
            string noTags = Regex.Replace(raw, "<[^>]+>", " ");
            return System.Net.WebUtility.HtmlDecode(noTags).Trim();
        }
        else if (ext == ".pdf")
        {
            string rawBytes = File.ReadAllText(srcPath, Encoding.Latin1);
            var matches = Regex.Matches(rawBytes, @"\(([^()\\]+)\)\s*Tj");
            if (matches.Count > 0)
            {
                return string.Join(Environment.NewLine, matches.Select(m => m.Groups[1].Value));
            }
        }

        return File.ReadAllText(srcPath, Encoding.UTF8);
    }

    private static void WriteOpenXmlDocx(string text, string outPath)
    {
        using var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write);
        using var zip = new ZipArchive(fs, ZipArchiveMode.Create);

        WriteZipText(zip, "[Content_Types].xml",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n" +
            "  <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>\n" +
            "  <Default Extension=\"xml\" ContentType=\"application/xml\"/>\n" +
            "  <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>\n" +
            "</Types>");

        WriteZipText(zip, "_rels/.rels",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
            "  <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>\n" +
            "</Relationships>");

        var sb = new StringBuilder();
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>");
        sb.AppendLine("<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>");
        foreach (string line in text.Replace("\r\n", "\n").Split('\n'))
        {
            string escaped = System.Security.SecurityElement.Escape(line) ?? "";
            sb.AppendLine($"<w:p><w:r><w:t>{escaped}</w:t></w:r></w:p>");
        }
        sb.AppendLine("</w:body></w:document>");
        WriteZipText(zip, "word/document.xml", sb.ToString());
    }

    private static void WriteMinimalEpub(string text, string title, string outPath)
    {
        using var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write);
        using var zip = new ZipArchive(fs, ZipArchiveMode.Create);
        WriteZipText(zip, "mimetype", "application/epub+zip");
        WriteZipText(zip, "META-INF/container.xml",
            "<?xml version=\"1.0\"?>\n" +
            "<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">\n" +
            "  <rootfiles><rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles>\n" +
            "</container>");

        WriteZipText(zip, "OEBPS/content.opf",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<package xmlns=\"http://www.idpf.org/2007/opf\" unique-identifier=\"BookId\" version=\"2.0\">\n" +
            $"  <metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>{System.Security.SecurityElement.Escape(title)}</dc:title><dc:language>en</dc:language></metadata>\n" +
            "  <manifest><item id=\"ch1\" href=\"chapter1.xhtml\" media-type=\"application/xhtml+xml\"/></manifest>\n" +
            "  <spine><itemref idref=\"ch1\"/></spine>\n" +
            "</package>");

        var bodyParas = string.Join("\n", text.Replace("\r\n", "\n").Split('\n').Select(l => $"<p>{System.Security.SecurityElement.Escape(l)}</p>"));
        WriteZipText(zip, "OEBPS/chapter1.xhtml",
            $"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>{System.Security.SecurityElement.Escape(title)}</title></head><body>\n{bodyParas}\n</body></html>");
    }

    public static void WriteTextPdf(IReadOnlyList<string> lines, string outPdfPath, string title)
    {
        const int width = 1240;
        const int height = 1754;
        var pages = new List<(byte[] JpegBytes, int Width, int Height)>();
        int linesPerPage = 48;
        int totalPages = Math.Max(1, (int)Math.Ceiling(lines.Count / (double)linesPerPage));

        for (int p = 0; p < totalPages; p++)
        {
            using var bmp = new Bitmap(width, height, PixelFormat.Format24bppRgb);
            using (var g = Graphics.FromImage(bmp))
            {
                g.Clear(Color.White);
                using var titleFont = new Font("Segoe UI", 20, FontStyle.Bold);
                using var bodyFont = new Font("Consolas", 14, FontStyle.Regular);
                using var brush = new SolidBrush(Color.FromArgb(20, 24, 35));
                float y = 64f;
                if (p == 0 && !string.IsNullOrWhiteSpace(title))
                {
                    g.DrawString(title, titleFont, brush, 64f, y);
                    y += 48f;
                }
                var slice = lines.Skip(p * linesPerPage).Take(linesPerPage);
                foreach (string line in slice)
                {
                    g.DrawString(line, bodyFont, brush, 64f, y);
                    y += 30f;
                }
            }
            using var ms = new MemoryStream();
            bmp.Save(ms, ImageFormat.Jpeg);
            pages.Add((ms.ToArray(), width, height));
        }

        WriteMinimalJpegPdf(pages, outPdfPath);
    }

    // ------------------------------------------------------------------------
    // 6. Media Pipeline (FFmpeg)
    // ------------------------------------------------------------------------
    private static void ConvertMediaWithFfmpeg(string srcPath, string outPath, ConversionFormat targetFormat, ConversionOptions options)
    {
        string? ffmpeg = FindExecutable("ffmpeg.exe");
        if (ffmpeg == null)
        {
            throw new InvalidOperationException("FFmpeg is required. Open Settings → General → Media Tools (FFmpeg) to set it up.");
        }

        var args = new List<string> { "-y", "-i", srcPath };
        if (!options.PreserveMetadata)
        {
            args.AddRange(new[] { "-map_metadata", "-1" });
        }

        if (targetFormat == ConversionFormat.Gif)
        {
            string vf = $"fps={options.GifFps},scale='min({options.GifWidth},iw)':-2:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse";
            args.AddRange(new[] { "-vf", vf, outPath });
        }
        else if (targetFormat.Category() == SupportedFormatGroup.Audio)
        {
            args.Add("-vn");
            string br = $"{options.AudioBitrateKbps}k";
            switch (targetFormat)
            {
                case ConversionFormat.Mp3:
                    args.AddRange(new[] { "-c:a", "libmp3lame", "-b:a", br });
                    break;
                case ConversionFormat.M4a:
                    args.AddRange(new[] { "-c:a", "aac", "-b:a", br });
                    break;
                case ConversionFormat.Flac:
                    args.AddRange(new[] { "-c:a", "flac" });
                    break;
                case ConversionFormat.Ogg:
                    args.AddRange(new[] { "-c:a", "libvorbis", "-b:a", br });
                    break;
                case ConversionFormat.Opus:
                    args.AddRange(new[] { "-c:a", "libopus", "-b:a", br });
                    break;
                case ConversionFormat.Wav:
                    args.AddRange(new[] { "-c:a", "pcm_s16le" });
                    break;
                case ConversionFormat.Aiff:
                    args.AddRange(new[] { "-c:a", "pcm_s16be" });
                    break;
            }
            args.Add(outPath);
        }
        else
        {
            int crf = options.Quality switch
            {
                ConversionQuality.Compact => 28,
                ConversionQuality.High => 18,
                _ => 23
            };
            if (options.VideoMaxHeight > 0)
            {
                args.AddRange(new[] { "-vf", $"scale=-2:'min({options.VideoMaxHeight},ih)'" });
            }
            if (targetFormat is ConversionFormat.Mp4 or ConversionFormat.Mov or ConversionFormat.Mkv)
            {
                args.AddRange(new[] { "-c:v", "libx264", "-crf", crf.ToString(CultureInfo.InvariantCulture), "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", $"{options.AudioBitrateKbps}k" });
            }
            args.Add(outPath);
        }

        RunExternalProcess(ffmpeg, args);
    }

    public static string? FindExecutable(string exeName)
    {
        if (exeName.Equals("ffmpeg.exe", StringComparison.OrdinalIgnoreCase) &&
            FfmpegSetupService.GetPreferredExecutable() is { } preferred)
            return preferred;

        string bundled = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", "Tools", exeName);
        if (File.Exists(bundled)) return bundled;

        string? pathEnv = Environment.GetEnvironmentVariable("PATH");
        if (!string.IsNullOrWhiteSpace(pathEnv))
        {
            foreach (string dir in pathEnv.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
            {
                try
                {
                    string candidate = Path.Combine(dir.Trim(), exeName);
                    if (File.Exists(candidate)) return candidate;
                }
                catch { }
            }
        }

        string wingetPackages = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WinGet", "Packages");
        if (Directory.Exists(wingetPackages))
        {
            try
            {
                string? match = Directory.EnumerateFiles(wingetPackages, exeName, SearchOption.AllDirectories).FirstOrDefault();
                if (match != null) return match;
            }
            catch { }
        }

        return null;
    }

    public static void RunExternalProcess(string executable, IReadOnlyList<string> arguments)
    {
        var psi = new ProcessStartInfo
        {
            FileName = executable,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };
        foreach (string a in arguments)
            psi.ArgumentList.Add(a);

        using var proc = Process.Start(psi) ?? throw new InvalidOperationException($"Failed to start {executable}");
        string stderr = proc.StandardError.ReadToEnd();
        proc.WaitForExit();
        if (proc.ExitCode != 0)
        {
            throw new InvalidOperationException($"Process {Path.GetFileName(executable)} failed ({proc.ExitCode}): {stderr}");
        }
    }

    private static void WriteZipText(ZipArchive zip, string entryName, string content)
    {
        var entry = zip.CreateEntry(entryName, CompressionLevel.Optimal);
        using var s = entry.Open();
        using var sw = new StreamWriter(s, new UTF8Encoding(false));
        sw.Write(content);
    }
}
