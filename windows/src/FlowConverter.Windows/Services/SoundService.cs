using System;
using System.IO;
using System.Media;
using FlowConverter.Windows.Models;

namespace FlowConverter.Windows.Services;

public sealed class SoundService
{
    public static SoundService Instance { get; } = new();

    private SoundPlayer? _highlightPlayer;
    private DateTime _lastPlayUtc = DateTime.MinValue;

    private SoundService()
    {
        try
        {
            string wavPath = AssetGenerator.EnsureHighlightSoundWav();
            if (File.Exists(wavPath))
            {
                _highlightPlayer = new SoundPlayer(wavPath);
                _highlightPlayer.LoadAsync();
            }
        }
        catch
        {
            // Ignore audio initialization errors on headless/no-audio systems
        }
    }

    public void PlayPetalHighlight()
    {
        if (!FlowConverterSettings.Instance.SoundsAndHapticsEnabled)
        {
            return;
        }

        DateTime now = DateTime.UtcNow;
        if ((now - _lastPlayUtc).TotalMilliseconds < 25)
        {
            return;
        }
        _lastPlayUtc = now;

        try
        {
            _highlightPlayer?.Play();
        }
        catch
        {
            // Ignore playback glitches
        }
    }
}
