using System.Buffers.Binary;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text.RegularExpressions;

namespace FlowConverter.Windows.Engines;

internal static partial class AudioTrimEngine
{
    private const int AnalysisRate = 16000;
    private const int WaveformBarCount = 120;

    public static async Task<(double Duration, double[] Peaks)> ReadWaveformAsync(string source, CancellationToken token)
    {
        var blocks = new List<int>();
        long bytes = 0;
        await RunAsync(new[] { "-i", source, "-map", "0:a:0", "-ac", "2", "-ar",
            AnalysisRate.ToString(CultureInfo.InvariantCulture), "-f", "s16le", "pipe:1" }, async stream =>
        {
            var buffer = new byte[AnalysisRate * 4 / 20]; // 50 ms of stereo PCM
            int read;
            while ((read = await stream.ReadAtLeastAsync(buffer, buffer.Length, false, token).ConfigureAwait(false)) > 0)
            {
                int peak = 0;
                for (int i = 0; i + 1 < read; i += 2)
                    peak = Math.Max(peak, Math.Abs((int)BinaryPrimitives.ReadInt16LittleEndian(buffer.AsSpan(i, 2))));
                blocks.Add(peak);
                bytes += read;
            }
        }, token).ConfigureAwait(false);

        if (blocks.Count == 0) throw new InvalidDataException("This file has no audio samples.");
        int maximum = Math.Max(1, blocks.Max());
        int barCount = Math.Min(WaveformBarCount, blocks.Count);
        var peaks = new double[barCount];
        for (int i = 0; i < blocks.Count; i++)
        {
            int bar = (int)((long)i * barCount / blocks.Count);
            peaks[bar] = Math.Max(peaks[bar], (double)blocks[i] / maximum);
        }
        return (bytes / (4.0 * AnalysisRate), peaks);
    }

    public static async Task TrimAsync(string source, string output, double start, double duration,
        bool trimSilence, double threshold, bool preview, CancellationToken token = default)
    {
        if (trimSilence)
            (start, duration) = await FindAudibleRangeAsync(source, start, duration, threshold, token).ConfigureAwait(false);

        var args = new List<string> { "-y", "-ss", Number(start), "-i", source,
            "-t", Number(duration), "-map", "0:a:0" };
        if (preview) args.AddRange(new[] { "-c:a", "pcm_s16le", "-ac", "2", "-ar", "44100" });
        args.Add(output);
        await RunAsync(args, null, token).ConfigureAwait(false);
    }

    private static async Task<(double Start, double Duration)> FindAudibleRangeAsync(
        string source, double start, double duration, double threshold, CancellationToken token)
    {
        string log = await RunAsync(new[] { "-ss", Number(start), "-t", Number(duration), "-i", source,
            "-map", "0:a:0", "-af", $"silencedetect=noise={Number(threshold)}dB:d=0.1",
            "-progress", "pipe:2", "-f", "null", "-" },
            null, token).ConfigureAwait(false);

        double leadingEnd = 0;
        double? trailingStart = null;
        double? silenceStart = null;
        double lastSilenceEnd = 0;
        foreach (Match match in SilenceEvent().Matches(log))
        {
            double position = double.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
            if (match.Groups[1].Value == "start")
            {
                silenceStart = position;
                trailingStart = null;
            }
            else if (silenceStart is double begins)
            {
                if (begins <= 0.01) leadingEnd = position;
                trailingStart = begins;
                lastSilenceEnd = position;
                silenceStart = null;
            }
        }

        // FFmpeg emits a final silence_end at EOF as well as when sound resumes.
        var progress = OutputTime().Matches(log);
        if (progress.Count > 0)
            duration = Math.Min(duration, double.Parse(progress[^1].Groups[1].Value, CultureInfo.InvariantCulture) / 1_000_000);
        if (lastSilenceEnd < duration - 0.005) trailingStart = null;
        double audibleEnd = Math.Min(duration, silenceStart ?? trailingStart ?? duration);
        if (audibleEnd <= leadingEnd)
            throw new InvalidOperationException("The selected range is silent at the current threshold.");

        return (start + leadingEnd, audibleEnd - leadingEnd);
    }

    private static string Number(double value) => value.ToString("0.######", CultureInfo.InvariantCulture);

    [GeneratedRegex(@"silence_(start|end):\s*(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)")]
    private static partial Regex SilenceEvent();

    [GeneratedRegex(@"out_time_us=(\d+)")]
    private static partial Regex OutputTime();

    private static async Task<string> RunAsync(IEnumerable<string> args, Func<Stream, Task>? readOutput,
        CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        string ffmpeg = UniversalConversionEngine.FindExecutable("ffmpeg.exe") ??
            throw new InvalidOperationException("Set up FFmpeg in Settings → General → Media Tools (FFmpeg).");
        var info = new ProcessStartInfo(ffmpeg)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = readOutput != null,
            RedirectStandardError = true
        };
        foreach (string arg in new[] { "-hide_banner", "-nostdin", "-nostats" }) info.ArgumentList.Add(arg);
        foreach (string arg in args) info.ArgumentList.Add(arg);

        using var process = Process.Start(info) ?? throw new IOException("Could not start FFmpeg.");
        using var registration = token.Register(() =>
        {
            try { process.Kill(); }
            catch (InvalidOperationException) { }
            catch (System.ComponentModel.Win32Exception) { }
        });
        Task<string> error = process.StandardError.ReadToEndAsync();
        Task output = readOutput?.Invoke(process.StandardOutput.BaseStream) ?? Task.CompletedTask;
        await Task.WhenAll(output, error, process.WaitForExitAsync()).ConfigureAwait(false);
        token.ThrowIfCancellationRequested();
        if (process.ExitCode != 0)
            throw new IOException(error.Result.Trim().Split('\n').LastOrDefault() ?? "FFmpeg could not process the audio.");
        return error.Result;
    }
}
