using System;
using System.Drawing;
using System.Windows.Forms;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Services;

public sealed class TrayIconService : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly Icon _idleIcon;
    private readonly ContextMenuStrip _menu;

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
        var iconResource = System.Windows.Application.GetResourceStream(
            new Uri("pack://application:,,,/FlowConverter;component/Resources/AppIcon.ico"));
        using var iconStream = iconResource.Stream;
        using var icon = new Icon(iconStream, SystemInformation.SmallIconSize);
        _idleIcon = (Icon)icon.Clone();

        var menu = _menu = new ContextMenuStrip
        {
            BackColor = MenuColors.FromTheme("ThemeCard"),
            ForeColor = MenuColors.FromTheme("ThemeText"),
            Renderer = new ToolStripProfessionalRenderer(new MenuColors()) { RoundedEdges = false },
            ShowImageMargin = false
        };
        var titleItem = new ToolStripMenuItem("Flow Converter (Windows)") { Enabled = false };
        menu.Items.Add(titleItem);
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(UiText.Get("Summon Conversion Wheel (Alt)"), null, (_, _) => SummonConvertWheelRequested?.Invoke());
        menu.Items.Add(UiText.Get("Summon File Tools Wheel (Shift)"), null, (_, _) => SummonToolsWheelRequested?.Invoke());
        menu.Items.Add(UiText.Get("Summon Quick Actions Wheel (Ctrl)"), null, (_, _) => SummonActionsWheelRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(UiText.Get("3D Printer .3MF Converter Studio…"), null, (_, _) => Open3MfStudioRequested?.Invoke());
        menu.Items.Add(UiText.Get("New Float Shelf…"), null, (_, _) => NewFloatShelfRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(UiText.Get("Getting Started…"), null, (_, _) => OpenWelcomeRequested?.Invoke());
        menu.Items.Add(UiText.Get("Settings…"), null, (_, _) => OpenSettingsRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(UiText.Get("Quit Flow Converter"), null, (_, _) => QuitRequested?.Invoke());

        _notifyIcon = new NotifyIcon
        {
            Icon = _idleIcon,
            Text = UiText.Get("Flow Converter — Alt+Drag to Convert"),
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
        _menu.Dispose();
        _idleIcon.Dispose();
    }

    private sealed class MenuColors : ProfessionalColorTable
    {
        public MenuColors() => UseSystemColors = false;

        public override Color ToolStripDropDownBackground => FromTheme("ThemeCard");
        public override Color MenuBorder => FromTheme("ThemeOutline");
        public override Color MenuItemBorder => FromTheme("ThemeOutline");
        public override Color MenuItemSelected => FromTheme("ThemeHover");
        public override Color SeparatorDark => FromTheme("ThemeBorder");
        public override Color SeparatorLight => FromTheme("ThemeBorder");

        public static Color FromTheme(string key)
        {
            var color = ThemeBrushes.Get(key).Color;
            return Color.FromArgb(color.A, color.R, color.G, color.B);
        }
    }
}
