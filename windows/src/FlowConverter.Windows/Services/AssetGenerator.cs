using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

namespace FlowConverter.Windows.Services;

public static class AssetGenerator
{
    public static string GetAssetsDirectory()
    {
        string baseDir = AppDomain.CurrentDomain.BaseDirectory;
        string resourcesDir = Path.Combine(baseDir, "Resources");
        Directory.CreateDirectory(resourcesDir);
        return resourcesDir;
    }

    public static string EnsureHighlightSoundWav()
    {
        string path = Path.Combine(GetAssetsDirectory(), "HighlightSound.wav");
        if (File.Exists(path) && new FileInfo(path).Length > 1000)
        {
            return path;
        }

        const int sampleRate = 44100;
        const double durationSeconds = 0.055;
        int numSamples = (int)(sampleRate * durationSeconds);
        int dataChunkSize = numSamples * 2; // 16-bit mono

        using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.Read);
        using var bw = new BinaryWriter(fs, Encoding.ASCII);

        // RIFF header
        bw.Write(Encoding.ASCII.GetBytes("RIFF"));
        bw.Write(36 + dataChunkSize);
        bw.Write(Encoding.ASCII.GetBytes("WAVE"));

        // fmt subchunk
        bw.Write(Encoding.ASCII.GetBytes("fmt "));
        bw.Write(16);
        bw.Write((short)1); // PCM
        bw.Write((short)1); // Mono
        bw.Write(sampleRate);
        bw.Write(sampleRate * 2);
        bw.Write((short)2);
        bw.Write((short)16);

        // data subchunk
        bw.Write(Encoding.ASCII.GetBytes("data"));
        bw.Write(dataChunkSize);

        for (int i = 0; i < numSamples; i++)
        {
            double t = (double)i / sampleRate;
            double envelope = Math.Exp(-t * 68.0);
            double attack = Math.Min(1.0, t / 0.0025);
            double f1 = Math.Sin(2.0 * Math.PI * 1046.50 * t); // C6
            double f2 = Math.Sin(2.0 * Math.PI * 1567.98 * t) * 0.45; // G6
            double sample = (f1 + f2) * 0.35 * envelope * attack;
            short pcm = (short)Math.Clamp(sample * short.MaxValue, short.MinValue, short.MaxValue);
            bw.Write(pcm);
        }

        return path;
    }

    public static string EnsureAppIconIco()
    {
        string path = Path.Combine(GetAssetsDirectory(), "AppIcon.ico");
        if (File.Exists(path) && new FileInfo(path).Length > 500)
        {
            return path;
        }

        using Bitmap bmp = RenderFlowConverterIconBitmap(256);
        WriteSinglePngIcon(bmp, path);
        return path;
    }

    public static Icon CreateTrayIcon(bool activeOperation = false)
    {
        using Bitmap bmp = RenderFlowConverterIconBitmap(64, activeOperation);
        IntPtr hIcon = bmp.GetHicon();
        Icon icon = (Icon)Icon.FromHandle(hIcon).Clone();
        Interop.NativeMethods.DestroyIcon(hIcon);
        return icon;
    }

    public static Bitmap RenderFlowConverterIconBitmap(int size, bool activeHighlight = false)
    {
        var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.Clear(Color.Transparent);

        float s = size;
        float pad = s * 0.06f;
        var rect = new RectangleF(pad, pad, s - pad * 2, s - pad * 2);
        float cornerRadius = s * 0.22f;

        // 1. Dark Obsidian Squircle Background
        using (GraphicsPath bgPath = CreateRoundedRectPath(rect, cornerRadius))
        {
            using var bgBrush = new LinearGradientBrush(
                rect,
                Color.FromArgb(255, 13, 18, 31),
                Color.FromArgb(255, 23, 33, 56),
                LinearGradientMode.ForwardDiagonal);
            g.FillPath(bgBrush, bgPath);

            using var borderPen = new Pen(Color.FromArgb(140, 0, 229, 255), Math.Max(1.2f, s * 0.02f));
            g.DrawPath(borderPen, bgPath);
        }

        // 2. 8 Radial Wheel Petals
        float cx = s * 0.5f;
        float cy = s * 0.5f;
        float innerR = s * 0.17f;
        float outerR = s * 0.37f;

        for (int i = 0; i < 8; i++)
        {
            float startDeg = -90f + i * 45f - 18f;
            float sweepDeg = 36f;
            bool isCyanHighlight = (i == 0 || i == 1 || i == 7);
            bool isOrangeActive = activeHighlight && (i == 1 || i == 2);

            Color petalColor;
            if (isOrangeActive)
            {
                petalColor = Color.FromArgb(245, 255, 107, 13);
            }
            else if (isCyanHighlight)
            {
                petalColor = Color.FromArgb(235, 0, 229, 255);
            }
            else
            {
                petalColor = Color.FromArgb(185, 72, 92, 148);
            }

            using GraphicsPath petalPath = CreateAnnularSectorPath(cx, cy, innerR, outerR, startDeg, sweepDeg);
            using var brush = new SolidBrush(petalColor);
            g.FillPath(brush, petalPath);
        }

        // 3. Center Hub Ring
        float hubR = s * 0.13f;
        var hubRect = new RectangleF(cx - hubR, cy - hubR, hubR * 2, hubR * 2);
        using (var hubBrush = new SolidBrush(Color.FromArgb(255, 16, 22, 36)))
        {
            g.FillEllipse(hubBrush, hubRect);
        }
        using (var hubPen = new Pen(Color.FromArgb(255, 0, 229, 255), Math.Max(1.5f, s * 0.025f)))
        {
            g.DrawEllipse(hubPen, hubRect);
        }

        // 4. "//" Flow Slash Accent in Center
        using (var slashPen = new Pen(Color.FromArgb(255, 0, 229, 255), Math.Max(1.5f, s * 0.028f))
        {
            StartCap = LineCap.Round,
            EndCap = LineCap.Round
        })
        {
            float dx = s * 0.025f;
            float dy = s * 0.045f;
            g.DrawLine(slashPen, cx - dx * 1.4f, cy + dy, cx - dx * 0.1f, cy - dy);
            g.DrawLine(slashPen, cx + dx * 0.1f, cy + dy, cx + dx * 1.4f, cy - dy);
        }

        return bmp;
    }

    private static GraphicsPath CreateRoundedRectPath(RectangleF rect, float radius)
    {
        var path = new GraphicsPath();
        float d = radius * 2f;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    private static GraphicsPath CreateAnnularSectorPath(float cx, float cy, float innerR, float outerR, float startDeg, float sweepDeg)
    {
        var path = new GraphicsPath();
        var outerRect = new RectangleF(cx - outerR, cy - outerR, outerR * 2, outerR * 2);
        var innerRect = new RectangleF(cx - innerR, cy - innerR, innerR * 2, innerR * 2);
        path.AddArc(outerRect, startDeg, sweepDeg);
        path.AddArc(innerRect, startDeg + sweepDeg, -sweepDeg);
        path.CloseFigure();
        return path;
    }

    private static void WriteSinglePngIcon(Bitmap bmp, string icoPath)
    {
        using var msPng = new MemoryStream();
        bmp.Save(msPng, ImageFormat.Png);
        byte[] pngBytes = msPng.ToArray();

        using var fs = new FileStream(icoPath, FileMode.Create, FileAccess.Write, FileShare.Read);
        using var bw = new BinaryWriter(fs);

        // ICONDIR header
        bw.Write((short)0); // Reserved
        bw.Write((short)1); // Type 1 = ICO
        bw.Write((short)1); // Count = 1 image

        // ICONDIRENTRY
        bw.Write((byte)(bmp.Width >= 256 ? 0 : bmp.Width));
        bw.Write((byte)(bmp.Height >= 256 ? 0 : bmp.Height));
        bw.Write((byte)0); // Color count
        bw.Write((byte)0); // Reserved
        bw.Write((short)1); // Planes
        bw.Write((short)32); // BitCount
        bw.Write(pngBytes.Length); // BytesInRes
        bw.Write(22); // ImageOffset (6 + 16)

        bw.Write(pngBytes);
    }
}
