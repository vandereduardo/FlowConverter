using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using FlowConverter.Windows.Models;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Services;

internal static class FfmpegSetupService
{
    private const string DownloadUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip";
    private static readonly HttpClient Client = new();
    private static readonly SemaphoreSlim InstallLock = new(1);
    private static string InstallDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FlowConverter", "Tools");
    private static string InstalledPath => Path.Combine(InstallDirectory, "ffmpeg.exe");

    public static string? GetPreferredExecutable()
    {
        string? configured = FlowConverterSettings.Instance.FfmpegExecutablePath;
        if (File.Exists(configured)) return configured;
        return File.Exists(InstalledPath) ? InstalledPath : null;
    }

    public static async Task<string> GetVersionAsync(string executable)
    {
        var startInfo = new ProcessStartInfo(executable, "-version")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true
        };
        using var process = Process.Start(startInfo) ?? throw new IOException(UiText.Get("Could not start FFmpeg."));
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        try
        {
            string output = await process.StandardOutput.ReadToEndAsync(timeout.Token);
            await process.WaitForExitAsync(timeout.Token);
            string firstLine = output.Split('\n', 2)[0].Trim();
            if (process.ExitCode != 0 || !firstLine.StartsWith("ffmpeg version ", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException(UiText.Get("The selected executable did not report an FFmpeg version."));
            return firstLine;
        }
        catch (OperationCanceledException)
        {
            if (!process.HasExited) process.Kill();
            throw new IOException(UiText.Get("FFmpeg did not respond in time."));
        }
    }

    public static async Task InstallAsync(IProgress<string> progress, CancellationToken cancellationToken)
    {
        await InstallLock.WaitAsync(cancellationToken);
        try
        {
            string staging = Path.Combine(InstallDirectory, $".ffmpeg-{Guid.NewGuid():N}");
            Directory.CreateDirectory(staging);
            try
            {
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                timeout.CancelAfter(TimeSpan.FromMinutes(10));
                var token = timeout.Token;
                string archivePath = Path.Combine(staging, "ffmpeg.zip");
                string checksum = (await Client.GetStringAsync(DownloadUrl + ".sha256", token)).Trim();
                if (checksum.Length != 64 || !checksum.All(Uri.IsHexDigit))
                    throw new InvalidDataException(UiText.Get("The FFmpeg provider returned an invalid SHA-256 checksum."));

                progress.Report(UiText.Get("Downloading FFmpeg…"));
                using (var response = await Client.GetAsync(DownloadUrl, HttpCompletionOption.ResponseHeadersRead, token))
                {
                    response.EnsureSuccessStatusCode();
                    await using var source = await response.Content.ReadAsStreamAsync(token);
                    await using var destination = File.Create(archivePath);
                    await source.CopyToAsync(destination, token);
                }

                progress.Report(UiText.Get("Verifying and installing FFmpeg…"));
                string stagedExecutable = Path.Combine(staging, "ffmpeg.exe");
                await using (var archiveStream = File.OpenRead(archivePath))
                {
                    byte[] hash = await SHA256.HashDataAsync(archiveStream, token);
                    if (!Convert.ToHexString(hash).Equals(checksum, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException(UiText.Get("The FFmpeg download failed its SHA-256 check. Please try again."));

                    archiveStream.Position = 0;
                    using var archive = new ZipArchive(archiveStream, ZipArchiveMode.Read, leaveOpen: true);
                    var executable = archive.Entries.SingleOrDefault(entry =>
                        entry.FullName.EndsWith("/bin/ffmpeg.exe", StringComparison.OrdinalIgnoreCase));
                    if (executable == null)
                        throw new InvalidDataException(UiText.Get("The FFmpeg archive did not contain ffmpeg.exe."));
                    await using var source = executable.Open();
                    await using var destination = File.Create(stagedExecutable);
                    await source.CopyToAsync(destination, token);
                }

                await GetVersionAsync(stagedExecutable);
                token.ThrowIfCancellationRequested();
                File.Move(stagedExecutable, InstalledPath, overwrite: true);
            }
            finally
            {
                try { Directory.Delete(staging, recursive: true); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }
        finally
        {
            InstallLock.Release();
        }
    }
}
