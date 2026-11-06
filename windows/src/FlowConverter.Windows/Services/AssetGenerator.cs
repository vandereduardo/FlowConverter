using System;
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
}
