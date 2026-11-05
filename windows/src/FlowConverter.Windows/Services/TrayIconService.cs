using System;
using System.Drawing;
using System.Windows.Forms;

namespace FlowConverter.Windows.Services;

public sealed class TrayIconService : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly Icon _idleIcon;

    public event Action? SummonConvertWheelRequested;
    public event Action? SummonToolsWheelRequested;
    public event Action? SummonActionsWheelRequested;
    public event Action? Open3MfStudioRequested;
    public event Action? NewFloatShelfRequested;
    public event Action? OpenWelcomeRequested;
    public event Action? OpenSettingsRequested;
    public event Action? QuitRequested;

    public TrayIconService()
    {
        _idleIcon = AssetGenerator.CreateTrayIcon(activeOperation: false);

        var menu = new ContextMenuStrip();
        var titleItem = new ToolStripMenuItem("Flow Converter (Windows)") { Enabled = false };
        menu.Items.Add(titleItem);
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add("Summon Conversion Wheel (Alt)", null, (_, _) => SummonConvertWheelRequested?.Invoke());
        menu.Items.Add("Summon File Tools Wheel (Shift)", null, (_, _) => SummonToolsWheelRequested?.Invoke());
        menu.Items.Add("Summon Quick Actions Wheel (Ctrl)", null, (_, _) => SummonActionsWheelRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add("3D Printer .3MF Converter Studio…", null, (_, _) => Open3MfStudioRequested?.Invoke());
        menu.Items.Add("New Float Shelf…", null, (_, _) => NewFloatShelfRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add("Getting Started…", null, (_, _) => OpenWelcomeRequested?.Invoke());
        menu.Items.Add("Settings…", null, (_, _) => OpenSettingsRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add("Quit Flow Converter", null, (_, _) => QuitRequested?.Invoke());

        _notifyIcon = new NotifyIcon
        {
            Icon = _idleIcon,
            Text = "Flow Converter — Alt+Drag to Convert",
            ContextMenuStrip = menu,
            Visible = true
        };

        _notifyIcon.DoubleClick += (_, _) => SummonConvertWheelRequested?.Invoke();
    }

    public void ShowNotification(string title, string message)
    {
        try
        {
            _notifyIcon.ShowBalloonTip(2500, title, message, ToolTipIcon.Info);
        }
        catch { }
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _idleIcon.Dispose();
    }
}
