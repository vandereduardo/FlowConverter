using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using FlowConverter.Windows.Models;

namespace FlowConverter.Windows.Engines;

public static class ToolExecutionEngine
{
    public static bool RequiresFfmpeg(FileTool tool, IReadOnlyList<string> paths) => tool switch
    {
        FileTool.MuteVideo or FileTool.TrimAudio or FileTool.TrimVideo or FileTool.ChangeVideoSpeed or
        FileTool.CropVideo or FileTool.NormalizeAudio or FileTool.AudioChannels or FileTool.AudioToVideo or
        FileTool.VideoSnapshots or FileTool.SplitVideo or FileTool.RedactVideo or FileTool.RedactAudio or
        FileTool.JoinVideos => true,
        FileTool.Compress or FileTool.RemoveMetadata => paths.Any(path =>
            ConversionFormatHelper.Detect(path)?.Category() is SupportedFormatGroup.Audio or SupportedFormatGroup.Video),
        _ => false
    };

    public static List<string> ExecuteBatch(
        FileTool tool,
        IReadOnlyList<string> inputPaths,
        FileToolExecutionOptions? options = null,
        Action<double, string>? progressCallback = null)
    {
        options ??= new FileToolExecutionOptions();
        var outputs = new List<string>();
        if (inputPaths.Count == 0) return outputs;

        switch (tool)
        {
            case FileTool.CreateArchive:
                progressCallback?.Invoke(0.2, "Creating ZIP archive...");
                outputs.Add(UniversalConversionEngine.PackItemsToArchive(inputPaths, ConversionFormat.Zip));
                progressCallback?.Invoke(1.0, "Archive ready.");
                return outputs;

            case FileTool.CreatePDF:
            {
                string first = inputPaths[0];
                string dir = Path.GetDirectoryName(first) ?? Environment.CurrentDirectory;
                string baseName = Path.GetFileNameWithoutExtension(first);
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Document", "pdf");
                progressCallback?.Invoke(0.3, "Building PDF from images...");
                UniversalConversionEngine.CreatePdfFromImages(inputPaths, outPath);
                outputs.Add(outPath);
                progressCallback?.Invoke(1.0, "PDF created.");
                return outputs;
            }

            case FileTool.CreateCollage:
                progressCallback?.Invoke(0.3, "Rendering photo collage...");
                outputs.Add(CreateImageCollage(inputPaths, options));
                progressCallback?.Invoke(1.0, "Collage saved.");
                return outputs;

            case FileTool.JoinVideos:
                progressCallback?.Invoke(0.3, "Joining video clips...");
                outputs.Add(JoinVideosWithFfmpeg(inputPaths));
                progressCallback?.Invoke(1.0, "Videos joined.");
                return outputs;

            case FileTool.MergePDF:
                progressCallback?.Invoke(0.3, "Merging PDF documents...");
                outputs.Add(MergePdfDocuments(inputPaths));
                progressCallback?.Invoke(1.0, "PDF merged.");
                return outputs;
        }

        for (int i = 0; i < inputPaths.Count; i++)
        {
            string src = inputPaths[i];
            progressCallback?.Invoke((double)i / inputPaths.Count, $"{tool.DisplayName()}: {Path.GetFileName(src)}");
            outputs.AddRange(ExecuteSingle(tool, src, options));
        }

        progressCallback?.Invoke(1.0, "Done.");
        return outputs;
    }

    public static List<string> ExecuteSingle(FileTool tool, string srcPath, FileToolExecutionOptions options)
    {
        string dir = Path.GetDirectoryName(srcPath) ?? Environment.CurrentDirectory;
        string baseName = UniversalConversionEngine.GetBaseNameWithoutCompoundExtension(srcPath);
        string ext = Path.GetExtension(srcPath).TrimStart('.');
        if (string.IsNullOrWhiteSpace(ext)) ext = "png";

        switch (tool)
        {
            case FileTool.Convert3MF:
            {
                var targetPrinter = options.TargetPrinter
                    ?? FlowConverterSettings.Instance.ConfiguredPrinters3D.FirstOrDefault()
                    ?? Printer3DModel.DefaultCatalog().First();
                string out3mf = ThreeMFConverterEngine.Convert(
                    srcPath,
                    targetPrinter,
                    options.OptimizationPreset,
                    options.RecenterOnBed,
                    options.PreserveFilaments);
                return new List<string> { out3mf };
            }

            case FileTool.ExtractArchive:
            {
                string outDir = ThreeMFConverterEngine.UniqueOutputPath(dir, baseName, "");
                UniversalConversionEngine.ExtractArchiveToDirectory(srcPath, outDir);
                return new List<string> { outDir };
            }

            case FileTool.RemoveMetadata:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Cleaned", ext);
                RemoveMetadata(srcPath, outPath);
                return new List<string> { outPath };
            }

            case FileTool.Compress:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Compressed", ext);
                CompressFile(srcPath, outPath, options);
                return new List<string> { outPath };
            }

            case FileTool.CropImage:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Cropped", ext);
                CropImageFile(srcPath, outPath, options.Crop);
                return new List<string> { outPath };
            }

            case FileTool.EditImage:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Edited", "png");
                AdjustImageFile(srcPath, outPath, options.Adjustments);
                return new List<string> { outPath };
            }

            case FileTool.FrameImage:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Framed", "png");
                FrameImageFile(srcPath, outPath, options);
                return new List<string> { outPath };
            }

            case FileTool.AnnotateImage:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Annotated", "png");
                AnnotateImageFile(srcPath, outPath, options.Annotations);
                return new List<string> { outPath };
            }

            case FileTool.RedactImage:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Redacted", "png");
                RedactImageFile(srcPath, outPath, options.RedactionRectangles, options.DefaultRedactionStyle);
                return new List<string> { outPath };
            }

            case FileTool.MuteVideo:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Muted", ext);
                RunFfmpegRequired(new[] { "-y", "-i", srcPath, "-c:v", "copy", "-an", outPath });
                return new List<string> { outPath };
            }

            case FileTool.TrimAudio:
            case FileTool.TrimVideo:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Trimmed", ext);
                double start = Math.Max(0, options.TrimStartSeconds);
                double duration = Math.Max(0.1, options.TrimEndSeconds > start ? options.TrimEndSeconds - start : 10.0);
                RunFfmpegRequired(new[]
                {
                    "-y",
                    "-ss", start.ToString("0.###", CultureInfo.InvariantCulture),
                    "-i", srcPath,
                    "-t", duration.ToString("0.###", CultureInfo.InvariantCulture),
                    outPath
                });
                return new List<string> { outPath };
            }

            case FileTool.ChangeVideoSpeed:
            {
                double spd = Math.Clamp(options.VideoSpeedMultiplier, 0.25, 4.0);
                string spdLabel = spd.ToString("0.##", CultureInfo.InvariantCulture);
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} {spdLabel}x", ext);
                string vf = string.Create(CultureInfo.InvariantCulture, $"setpts=(PTS-STARTPTS)/{spd:0.###}");
                string af = string.Create(CultureInfo.InvariantCulture, $"atempo={Math.Clamp(spd, 0.5, 2.0):0.###}");
                RunFfmpegRequired(new[] { "-y", "-i", srcPath, "-vf", vf, "-af", af, "-c:v", "libx264", "-crf", "21", "-c:a", "aac", outPath });
                return new List<string> { outPath };
            }

            case FileTool.CropVideo:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Cropped", ext);
                var c = options.Crop;
                string vf = string.Create(CultureInfo.InvariantCulture,
                    $"crop=trunc(iw*{c.NormalizedWidth:0.####}/2)*2:trunc(ih*{c.NormalizedHeight:0.####}/2)*2:trunc(iw*{c.NormalizedX:0.####}/2)*2:trunc(ih*{c.NormalizedY:0.####}/2)*2");
                RunFfmpegRequired(new[] { "-y", "-i", srcPath, "-vf", vf, "-c:v", "libx264", "-crf", "21", "-c:a", "copy", outPath });
                return new List<string> { outPath };
            }

            case FileTool.NormalizeAudio:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Normalized", ext);
                string af = string.Create(CultureInfo.InvariantCulture, $"loudnorm=I={options.TargetLufs:0.#}:LRA=11:TP=-1.5");
                RunFfmpegRequired(new[] { "-y", "-i", srcPath, "-af", af, outPath });
                return new List<string> { outPath };
            }

            case FileTool.AudioChannels:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Channels", ext);
                string af = options.ForceMono
                    ? "aformat=channel_layouts=mono"
                    : string.Create(CultureInfo.InvariantCulture, $"aformat=channel_layouts=stereo,pan=stereo|c0={options.LeftGain:0.##}*c0|c1={options.RightGain:0.##}*c1");
                RunFfmpegRequired(new[] { "-y", "-i", srcPath, "-af", af, outPath });
                return new List<string> { outPath };
            }

            case FileTool.AudioToVideo:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Visualizer", "mp4");
                int w = Math.Max(640, options.VisualizerWidth);
                int h = Math.Max(360, options.VisualizerHeight);
                string filter = $"color=c=0x121214:s={w}x{h}:r=30[bg];[0:a]showwaves=s={w}x{h}:mode=cline:rate=30:colors=0xff5200:scale=sqrt,format=yuva420p[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2:shortest=1,format=yuv420p[v]";
                RunFfmpegRequired(new[]
                {
                    "-y", "-i", srcPath,
                    "-filter_complex", filter,
                    "-map", "[v]", "-map", "0:a:0",
                    "-c:v", "libx264", "-crf", "21",
                    "-c:a", "aac", "-b:a", "192k", "-shortest",
                    outPath
                });
                return new List<string> { outPath };
            }

            case FileTool.VideoSnapshots:
            {
                var times = options.SnapshotTimestampsSeconds.Count > 0 ? options.SnapshotTimestampsSeconds : new List<double> { 1.0, 3.0, 5.0 };
                var outs = new List<string>();
                for (int idx = 0; idx < times.Count; idx++)
                {
                    double t = times[idx];
                    string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} - Frame {idx + 1:D3}", "png");
                    RunFfmpegRequired(new[] { "-y", "-ss", t.ToString("0.###", CultureInfo.InvariantCulture), "-i", srcPath, "-frames:v", "1", outPath });
                    outs.Add(outPath);
                }
                return outs;
            }

            case FileTool.SplitVideo:
            {
                var pts = new List<double> { 0.0 };
                pts.AddRange(options.SplitPointsSeconds.Where(x => x > 0.1).OrderBy(x => x));
                var outs = new List<string>();
                for (int i = 0; i < pts.Count; i++)
                {
                    double start = pts[i];
                    string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Part {i + 1}", ext);
                    var args = new List<string> { "-y", "-ss", start.ToString("0.###", CultureInfo.InvariantCulture), "-i", srcPath };
                    if (i + 1 < pts.Count)
                    {
                        double dur = Math.Max(0.1, pts[i + 1] - start);
                        args.AddRange(new[] { "-t", dur.ToString("0.###", CultureInfo.InvariantCulture) });
                    }
                    args.AddRange(new[] { "-c:v", "libx264", "-crf", "21", "-c:a", "aac", outPath });
                    RunFfmpegRequired(args);
                    outs.Add(outPath);
                }
                return outs;
            }

            case FileTool.RedactVideo:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Redacted", ext);
                if (options.RedactionRectangles.Count == 0)
                {
                    File.Copy(srcPath, outPath, overwrite: true);
                    return new List<string> { outPath };
                }
                var boxes = new List<string>();
                foreach (var r in options.RedactionRectangles)
                {
                    string rx = Math.Clamp(r.NormalizedX, 0, 0.98).ToString("0.####", CultureInfo.InvariantCulture);
                    string ry = Math.Clamp(r.NormalizedY, 0, 0.98).ToString("0.####", CultureInfo.InvariantCulture);
                    string rw = Math.Clamp(r.NormalizedW, 0.01, 1.0 - r.NormalizedX).ToString("0.####", CultureInfo.InvariantCulture);
                    string rh = Math.Clamp(r.NormalizedH, 0.01, 1.0 - r.NormalizedY).ToString("0.####", CultureInfo.InvariantCulture);
                    string box = $"drawbox=x=iw*{rx}:y=ih*{ry}:w=iw*{rw}:h=ih*{rh}:color=black@1:t=fill";
                    if (r.EndTimeSeconds > r.StartTimeSeconds)
                    {
                        box += string.Create(CultureInfo.InvariantCulture, $":enable='between(t,{r.StartTimeSeconds:0.###},{r.EndTimeSeconds:0.###})'");
                    }
                    boxes.Add(box);
                }
                RunFfmpegRequired(new[] { "-y", "-i", srcPath, "-vf", string.Join(",", boxes), "-c:v", "libx264", "-crf", "21", "-c:a", "copy", outPath });
                return new List<string> { outPath };
            }

            case FileTool.RedactAudio:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Bleeped", ext);
                var ranges = options.AudioBleepRanges.Count > 0
                    ? options.AudioBleepRanges
                    : new List<RedactionTimeRange> { new() { StartSeconds = 0.0, EndSeconds = 1.5 } };
                string conds = string.Join("+", ranges.Select(r => string.Create(CultureInfo.InvariantCulture, $"between(t,{r.StartSeconds:0.###},{r.EndSeconds:0.###})")));
                string af = $"asetpts=PTS-STARTPTS,aeval=exprs='if(gt({conds},0),0.18*sin(2*PI*1000*t),val(ch))':c=same";
                RunFfmpegRequired(new[] { "-y", "-i", srcPath, "-af", af, outPath });
                return new List<string> { outPath };
            }

            case FileTool.SplitPDF:
            case FileTool.OrganizePDF:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} {tool.DisplayName()}", "pdf");
                File.Copy(srcPath, outPath, overwrite: true);
                return new List<string> { outPath };
            }

            default:
            {
                string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Processed", ext);
                File.Copy(srcPath, outPath, overwrite: true);
                return new List<string> { outPath };
            }
        }
    }

    private static void RemoveMetadata(string srcPath, string outPath)
    {
        ConversionFormat? fmt = ConversionFormatHelper.Detect(srcPath);
        if (fmt != null && fmt.Value.Category() == SupportedFormatGroup.Images)
        {
            using var src = new Bitmap(srcPath);
            using var clean = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(clean))
            {
                g.DrawImage(src, 0, 0, src.Width, src.Height);
            }
            UniversalConversionEngine.SaveBitmapWithFormat(clean, outPath, fmt.Value);
            return;
        }

        string? ffmpeg = UniversalConversionEngine.FindExecutable("ffmpeg.exe");
        if (ffmpeg != null)
        {
            UniversalConversionEngine.RunExternalProcess(ffmpeg, new[] { "-y", "-i", srcPath, "-map_metadata", "-1", "-c", "copy", outPath });
            return;
        }

        File.Copy(srcPath, outPath, overwrite: true);
    }

    private static void CompressFile(string srcPath, string outPath, FileToolExecutionOptions options)
    {
        ConversionFormat? fmt = ConversionFormatHelper.Detect(srcPath);
        if (fmt != null && fmt.Value.Category() == SupportedFormatGroup.Images)
        {
            using var src = new Bitmap(srcPath);
            int maxEdge = options.CompressionMaxEdgePixels > 0 ? options.CompressionMaxEdgePixels : 1920;
            int w = src.Width;
            int h = src.Height;
            if (Math.Max(w, h) > maxEdge)
            {
                double scale = (double)maxEdge / Math.Max(w, h);
                w = Math.Max(1, (int)Math.Round(w * scale));
                h = Math.Max(1, (int)Math.Round(h * scale));
            }
            using var resized = new Bitmap(w, h, PixelFormat.Format24bppRgb);
            using (var g = Graphics.FromImage(resized))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.Clear(Color.White);
                g.DrawImage(src, 0, 0, w, h);
            }
            UniversalConversionEngine.SaveBitmapWithFormat(resized, outPath, ConversionFormat.Jpg, ConversionQuality.Compact);
            return;
        }

        string? ffmpeg = UniversalConversionEngine.FindExecutable("ffmpeg.exe");
        if (ffmpeg != null)
        {
            UniversalConversionEngine.RunExternalProcess(ffmpeg, new[] { "-y", "-i", srcPath, "-c:v", "libx264", "-crf", "28", "-c:a", "aac", "-b:a", "128k", outPath });
            return;
        }

        File.Copy(srcPath, outPath, overwrite: true);
    }

    public static void CropImageFile(string srcPath, string outPath, CropSelection crop)
    {
        using var src = new Bitmap(srcPath);
        int x = (int)Math.Clamp(Math.Round(crop.NormalizedX * src.Width), 0, Math.Max(0, src.Width - 2));
        int y = (int)Math.Clamp(Math.Round(crop.NormalizedY * src.Height), 0, Math.Max(0, src.Height - 2));
        int w = (int)Math.Clamp(Math.Round(crop.NormalizedWidth * src.Width), 2, src.Width - x);
        int h = (int)Math.Clamp(Math.Round(crop.NormalizedHeight * src.Height), 2, src.Height - y);

        using var cropped = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(cropped))
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.DrawImage(src, new Rectangle(0, 0, w, h), new Rectangle(x, y, w, h), GraphicsUnit.Pixel);
        }
        var fmt = ConversionFormatHelper.Detect(outPath) ?? ConversionFormat.Png;
        UniversalConversionEngine.SaveBitmapWithFormat(cropped, outPath, fmt);
    }

    public static void AdjustImageFile(string srcPath, string outPath, ImageAdjustments adj)
    {
        using var src = new Bitmap(srcPath);
        using var dst = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(dst))
        {
            float contrast = (float)Math.Max(0.2, 1.0 + adj.Contrast);
            float brightness = (float)(adj.Brightness + adj.Exposure * 0.25);
            var cm = new ColorMatrix(new float[][]
            {
                new[] { contrast, 0, 0, 0, 0 },
                new[] { 0, contrast, 0, 0, 0 },
                new[] { 0, 0, contrast, 0, 0 },
                new[] { 0, 0, 0, 1f, 0 },
                new[] { brightness, brightness, brightness, 0, 1f }
            });
            using var ia = new ImageAttributes();
            ia.SetColorMatrix(cm);
            g.DrawImage(src, new Rectangle(0, 0, src.Width, src.Height), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel, ia);
        }
        dst.Save(outPath, ImageFormat.Png);
    }

    public static void FrameImageFile(string srcPath, string outPath, FileToolExecutionOptions options)
    {
        using var src = new Bitmap(srcPath);
        int pad = Math.Max(12, options.FramePadding);
        int canvasW = src.Width + pad * 2;
        int canvasH = src.Height + pad * 2;
        var preset = options.FramePreset ?? FrameBackgroundPreset.AllPresets.First();

        using var dst = new Bitmap(canvasW, canvasH, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(dst))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            Color c1 = ColorTranslator.FromHtml(preset.StartHex);
            Color c2 = ColorTranslator.FromHtml(preset.EndHex);
            using var bgBrush = new LinearGradientBrush(new Rectangle(0, 0, canvasW, canvasH), c1, c2, 45f);
            g.FillRectangle(bgBrush, 0, 0, canvasW, canvasH);

            using var shadowBrush = new SolidBrush(Color.FromArgb(100, 0, 0, 0));
            g.FillRectangle(shadowBrush, pad + 6, pad + 10, src.Width, src.Height);
            g.DrawImage(src, pad, pad, src.Width, src.Height);
        }
        dst.Save(outPath, ImageFormat.Png);
    }

    public static void AnnotateImageFile(string srcPath, string outPath, IReadOnlyList<AnnotationItem> items)
    {
        using var src = new Bitmap(srcPath);
        using var dst = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(dst))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.DrawImage(src, 0, 0, src.Width, src.Height);
            foreach (var item in items)
            {
                Color c = ColorTranslator.FromHtml(string.IsNullOrWhiteSpace(item.ColorHex) ? "#00E5FF" : item.ColorHex);
                float rx = (float)(item.NormalizedX * src.Width);
                float ry = (float)(item.NormalizedY * src.Height);
                float rw = (float)(Math.Max(0.08, item.NormalizedW) * src.Width);
                float rh = (float)(Math.Max(0.08, item.NormalizedH) * src.Height);
                using var pen = new Pen(c, Math.Max(2f, (float)item.StrokeWidth));
                if (item.ShapeType == "ellipse")
                    g.DrawEllipse(pen, rx, ry, rw, rh);
                else if (item.ShapeType == "text" && !string.IsNullOrWhiteSpace(item.Text))
                {
                    using var font = new Font("Segoe UI", Math.Max(14f, src.Width * 0.025f), FontStyle.Bold);
                    using var brush = new SolidBrush(c);
                    g.DrawString(item.Text, font, brush, rx, ry);
                }
                else
                    g.DrawRectangle(pen, rx, ry, rw, rh);
            }
        }
        dst.Save(outPath, ImageFormat.Png);
    }

    public static void RedactImageFile(string srcPath, string outPath, IReadOnlyList<RedactionRectangle> rects, RedactionStyle defaultStyle)
    {
        using var src = new Bitmap(srcPath);
        using var dst = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(dst))
        {
            g.DrawImage(src, 0, 0, src.Width, src.Height);
            foreach (var r in rects)
            {
                int rx = (int)Math.Clamp(r.NormalizedX * src.Width, 0, src.Width - 2);
                int ry = (int)Math.Clamp(r.NormalizedY * src.Height, 0, src.Height - 2);
                int rw = (int)Math.Clamp(r.NormalizedW * src.Width, 2, src.Width - rx);
                int rh = (int)Math.Clamp(r.NormalizedH * src.Height, 2, src.Height - ry);

                if (r.Style == RedactionStyle.Blur || defaultStyle == RedactionStyle.Blur || r.Style == RedactionStyle.Pixelate)
                {
                    int tinyW = Math.Max(2, rw / 18);
                    int tinyH = Math.Max(2, rh / 18);
                    using var small = new Bitmap(tinyW, tinyH);
                    using (var gs = Graphics.FromImage(small))
                    {
                        gs.InterpolationMode = InterpolationMode.Bilinear;
                        gs.DrawImage(src, new Rectangle(0, 0, tinyW, tinyH), new Rectangle(rx, ry, rw, rh), GraphicsUnit.Pixel);
                    }
                    g.InterpolationMode = InterpolationMode.NearestNeighbor;
                    g.DrawImage(small, new Rectangle(rx, ry, rw, rh));
                }
                else
                {
                    using var blackBrush = new SolidBrush(Color.Black);
                    g.FillRectangle(blackBrush, rx, ry, rw, rh);
                }
            }
        }
        dst.Save(outPath, ImageFormat.Png);
    }

    private static string CreateImageCollage(IReadOnlyList<string> imagePaths, FileToolExecutionOptions options)
    {
        string first = imagePaths[0];
        string dir = Path.GetDirectoryName(first) ?? Environment.CurrentDirectory;
        string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, "Collage", "png");

        var bitmaps = new List<Bitmap>();
        try
        {
            foreach (string p in imagePaths)
            {
                if (File.Exists(p)) bitmaps.Add(new Bitmap(p));
            }
            if (bitmaps.Count == 0) throw new InvalidOperationException("No valid images for collage.");

            int cols = Math.Max(1, options.CollageColumns);
            int rows = (int)Math.Ceiling(bitmaps.Count / (double)cols);
            int canvasW = Math.Max(640, options.CollageCanvasWidth);
            int pad = Math.Max(8, options.CollagePadding);
            int spacing = Math.Max(4, options.CollageSpacing);
            int cellW = (canvasW - pad * 2 - (cols - 1) * spacing) / cols;
            int cellH = (int)(cellW * 0.75);
            int canvasH = pad * 2 + rows * cellH + Math.Max(0, rows - 1) * spacing;

            using var canvas = new Bitmap(canvasW, canvasH, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(canvas))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.Clear(ColorTranslator.FromHtml(string.IsNullOrWhiteSpace(options.CollageBackgroundHex) ? "#14161D" : options.CollageBackgroundHex));

                for (int i = 0; i < bitmaps.Count; i++)
                {
                    int r = i / cols;
                    int c = i % cols;
                    int x = pad + c * (cellW + spacing);
                    int y = pad + r * (cellH + spacing);
                    g.DrawImage(bitmaps[i], x, y, cellW, cellH);
                }
            }
            canvas.Save(outPath, ImageFormat.Png);
            return outPath;
        }
        finally
        {
            foreach (var b in bitmaps) b.Dispose();
        }
    }

    private static string JoinVideosWithFfmpeg(IReadOnlyList<string> videoPaths)
    {
        string first = videoPaths[0];
        string dir = Path.GetDirectoryName(first) ?? Environment.CurrentDirectory;
        string baseName = Path.GetFileNameWithoutExtension(first);
        string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Joined", "mp4");
        string listFile = Path.Combine(Path.GetTempPath(), $"flowconverter-join-{Guid.NewGuid():N}.txt");
        try
        {
            var lines = videoPaths.Select(p => $"file '{p.Replace("'", "'\\''")}'");
            File.WriteAllLines(listFile, lines, new UTF8Encoding(false));
            RunFfmpegRequired(new[] { "-y", "-f", "concat", "-safe", "0", "-i", listFile, "-c", "copy", outPath });
            return outPath;
        }
        finally
        {
            try { File.Delete(listFile); } catch { }
        }
    }

    private static string MergePdfDocuments(IReadOnlyList<string> pdfPaths)
    {
        string first = pdfPaths[0];
        string dir = Path.GetDirectoryName(first) ?? Environment.CurrentDirectory;
        string baseName = Path.GetFileNameWithoutExtension(first);
        string outPath = ThreeMFConverterEngine.UniqueOutputPath(dir, $"{baseName} Merged", "pdf");
        var combinedLines = new List<string>();
        foreach (string p in pdfPaths)
        {
            combinedLines.Add($"=== {Path.GetFileName(p)} ===");
            combinedLines.AddRange(UniversalConversionEngine.ExtractDocumentText(p).Replace("\r\n", "\n").Split('\n'));
            combinedLines.Add("");
        }
        UniversalConversionEngine.WriteTextPdf(combinedLines, outPath, $"{baseName} Merged");
        return outPath;
    }

    private static void RunFfmpegRequired(IReadOnlyList<string> args)
    {
        string? ffmpeg = UniversalConversionEngine.FindExecutable("ffmpeg.exe");
        if (ffmpeg == null)
            throw new InvalidOperationException("FFmpeg is required. Open Settings → General → Media Tools (FFmpeg) to set it up.");
        UniversalConversionEngine.RunExternalProcess(ffmpeg, args);
    }
}
