#nullable enable
// FlowConverter - Clean-Room 100% MIT Open Source
// Views/FloatingShelfWindow.xaml.cs - Floating Drop Shelf Window ("Float")

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using FlowConverter.Windows.Models;
using DragEventArgs = System.Windows.DragEventArgs;
using MouseEventArgs = System.Windows.Input.MouseEventArgs;
using Point = System.Windows.Point;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Views;

/// <summary>
/// Implements the "Float" drop shelf window matching macOS FloatingShelfWindow.
/// Supports expanded (290x340) and compact (104x112) floating modes.
/// </summary>
public partial class FloatingShelfWindow : Window
{
    private static readonly List<FloatingShelfWindow> _openShelves = new();
    public static FloatingShelfWindow? ActiveShelf => _openShelves.LastOrDefault(s => s.IsVisible);

    /// <summary>
    /// Static event raised when the user clicks "Convert All..." on the shelf.
    /// </summary>
    public static event Action<IReadOnlyList<string>>? ConvertRequested;

    public ObservableCollection<ShelfItem> Items { get; } = new();

    private bool _isGridView = true;
    private bool _isCompact = false;
    private Point _dragStartPoint;
    private Point _compactMouseDownPos;
    private bool _compactDragging;

    public FloatingShelfWindow() : this(Array.Empty<string>())
    {
    }

    public FloatingShelfWindow(IEnumerable<string> initialFiles)
    {
        InitializeComponent();

        _openShelves.Add(this);

        GridItemsControl.ItemsSource = Items;
        ListItemsControl.ItemsSource = Items;

        if (initialFiles != null)
        {
            AddPaths(initialFiles);
        }
        else
        {
            UpdateView();
        }
    }

    protected override void OnClosed(EventArgs e)
    {
        base.OnClosed(e);
        _openShelves.Remove(this);
    }

    #region Static Manager Methods

    /// <summary>
    /// Adds files to the shelf, respecting FlowConverterSettings.Instance.FloatBehavior.
    /// Either adds files to the currently active shelf or creates a new one.
    /// </summary>
    public static void AddFilesToShelf(IEnumerable<string> filePaths)
    {
        if (Application.Current != null && !Application.Current.Dispatcher.CheckAccess())
        {
            Application.Current.Dispatcher.Invoke(() => AddFilesToShelf(filePaths));
            return;
        }

        var validPaths = filePaths?
            .Where(p => !string.IsNullOrWhiteSpace(p) && (File.Exists(p) || Directory.Exists(p)))
            .ToList() ?? new List<string>();

        if (validPaths.Count == 0) return;

        var behavior = FlowConverterSettings.Instance.FloatBehavior;
        if (behavior == FloatWheelBehavior.AddToExisting && ActiveShelf != null)
        {
            ActiveShelf.AddPaths(validPaths);
            if (ActiveShelf.WindowState == WindowState.Minimized)
            {
                ActiveShelf.WindowState = WindowState.Normal;
            }
            ActiveShelf.Show();
            ActiveShelf.Activate();
        }
        else
        {
            var shelf = new FloatingShelfWindow(validPaths);
            shelf.Show();
            shelf.Activate();
        }
    }

    /// <summary>
    /// Creates and displays a new empty floating drop shelf.
    /// </summary>
    public static void CreateNewEmptyShelf()
    {
        if (Application.Current != null && !Application.Current.Dispatcher.CheckAccess())
        {
            Application.Current.Dispatcher.Invoke(CreateNewEmptyShelf);
            return;
        }

        var shelf = new FloatingShelfWindow();
        shelf.Show();
        shelf.Activate();
    }

    #endregion

    #region Shelf Management & Visual States

    public void AddPaths(IEnumerable<string> paths)
    {
        if (paths == null) return;

        var existing = new HashSet<string>(Items.Select(i => i.FilePath), StringComparer.OrdinalIgnoreCase);
        foreach (var path in paths)
        {
            if (string.IsNullOrWhiteSpace(path)) continue;
            try
            {
                string full = Path.GetFullPath(path);
                if (!existing.Contains(full) && (File.Exists(full) || Directory.Exists(full)))
                {
                    existing.Add(full);
                    Items.Add(ShelfItem.FromPath(full));
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[FloatingShelfWindow] Invalid file path '{path}': {ex.Message}");
            }
        }

        UpdateView();
    }

    private void UpdateView()
    {
        int count = Items.Count;
        TitleTextBlock.Text = UiText.Format("Float ({0})", count);
        CompactCountTextBlock.Text = count == 1 ? UiText.Get("1 file") : UiText.Format("{0} files", count);

        bool hasItems = count > 0;
        EmptyPlaceholderBorder.Visibility = hasItems ? Visibility.Collapsed : Visibility.Visible;

        if (!hasItems)
        {
            GridItemsScrollViewer.Visibility = Visibility.Collapsed;
            ListItemsScrollViewer.Visibility = Visibility.Collapsed;
        }
        else if (_isGridView)
        {
            GridItemsScrollViewer.Visibility = Visibility.Visible;
            ListItemsScrollViewer.Visibility = Visibility.Collapsed;
            ToggleViewModeIcon.Text = "☰";
        }
        else
        {
            GridItemsScrollViewer.Visibility = Visibility.Collapsed;
            ListItemsScrollViewer.Visibility = Visibility.Visible;
            ToggleViewModeIcon.Text = "☷";
        }
    }

    private void SetCompactMode(bool compact)
    {
        _isCompact = compact;
        if (compact)
        {
            Width = 104;
            Height = 112;
            ExpandedRoot.Visibility = Visibility.Collapsed;
            CompactRoot.Visibility = Visibility.Visible;
            CompactCountTextBlock.Text = Items.Count == 1 ? UiText.Get("1 file") : UiText.Format("{0} files", Items.Count);
        }
        else
        {
            Width = 290;
            Height = 340;
            CompactRoot.Visibility = Visibility.Collapsed;
            ExpandedRoot.Visibility = Visibility.Visible;
            UpdateView();
        }
    }

    #endregion

    #region Drag & Drop Window Handling

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            e.Effects = DragDropEffects.Copy;
            e.Handled = true;
        }
        else
        {
            e.Effects = DragDropEffects.None;
        }
    }

    private void Window_Drop(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            if (e.Data.GetData(DataFormats.FileDrop) is string[] files)
            {
                AddPaths(files);
            }
            e.Handled = true;
        }
    }

    #endregion

    #region Window Controls & Mode Toggling

    private void Header_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void ToggleViewMode_Click(object sender, RoutedEventArgs e)
    {
        _isGridView = !_isGridView;
        UpdateView();
    }

    private void CollapseButton_Click(object sender, RoutedEventArgs e)
    {
        SetCompactMode(true);
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }

    private void CompactRoot_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _compactMouseDownPos = e.GetPosition(this);
        _compactDragging = false;
    }

    private void CompactRoot_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed)
        {
            Point pos = e.GetPosition(this);
            if (Math.Abs(pos.X - _compactMouseDownPos.X) > 4 || Math.Abs(pos.Y - _compactMouseDownPos.Y) > 4)
            {
                _compactDragging = true;
                DragMove();
            }
        }
    }

    private void CompactRoot_PreviewMouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_compactDragging)
        {
            SetCompactMode(false);
        }
    }

    #endregion

    #region Item Interactions & Drag-Out

    private void Item_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _dragStartPoint = e.GetPosition(null);
    }

    private void Item_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed)
        {
            Point current = e.GetPosition(null);
            Vector diff = _dragStartPoint - current;
            if (Math.Abs(diff.X) > SystemParameters.MinimumHorizontalDragDistance ||
                Math.Abs(diff.Y) > SystemParameters.MinimumVerticalDragDistance)
            {
                if (sender is FrameworkElement elem && elem.DataContext is ShelfItem item)
                {
                    try
                    {
                        var data = new DataObject(DataFormats.FileDrop, new string[] { item.FilePath });
                        DragDrop.DoDragDrop(elem, data, DragDropEffects.Copy | DragDropEffects.Move);
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"[FloatingShelfWindow] DragDrop failed: {ex.Message}");
                    }
                }
            }
        }
    }

    private void Item_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2 && sender is FrameworkElement elem && elem.DataContext is ShelfItem item)
        {
            try
            {
                Process.Start(new ProcessStartInfo(item.FilePath) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[FloatingShelfWindow] Open file failed: {ex.Message}");
            }
        }
    }

    private void RemoveItemButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement elem && elem.DataContext is ShelfItem item)
        {
            Items.Remove(item);
            UpdateView();
        }
    }

    #endregion

    #region Context Menu Handlers

    private ShelfItem? GetItemFromSender(object sender)
    {
        if (sender is MenuItem mi)
        {
            if (mi.DataContext is ShelfItem direct) return direct;
            if (mi.Parent is ContextMenu cm && cm.PlacementTarget is FrameworkElement fe && fe.DataContext is ShelfItem fromFe)
            {
                return fromFe;
            }
        }
        return null;
    }

    private void MenuItemOpen_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItemFromSender(sender);
        if (item != null && (File.Exists(item.FilePath) || Directory.Exists(item.FilePath)))
        {
            try
            {
                Process.Start(new ProcessStartInfo(item.FilePath) { UseShellExecute = true });
            }
            catch { }
        }
    }

    private void MenuItemReveal_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItemFromSender(sender);
        if (item != null && (File.Exists(item.FilePath) || Directory.Exists(item.FilePath)))
        {
            try
            {
                Process.Start("explorer.exe", $"/select,\"{item.FilePath}\"");
            }
            catch { }
        }
    }

    private void MenuItemCopyFile_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItemFromSender(sender);
        if (item != null)
        {
            var sc = new System.Collections.Specialized.StringCollection { item.FilePath };
            Clipboard.SetFileDropList(sc);
        }
    }

    private void MenuItemCopyPath_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItemFromSender(sender);
        if (item != null)
        {
            Clipboard.SetText(item.FilePath);
        }
    }

    private void MenuItemRemove_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItemFromSender(sender);
        if (item != null)
        {
            Items.Remove(item);
            UpdateView();
        }
    }

    #endregion

    #region Footer Actions

    private void CopyAll_Click(object sender, RoutedEventArgs e)
    {
        if (Items.Count == 0) return;

        var sc = new System.Collections.Specialized.StringCollection();
        foreach (var item in Items)
        {
            sc.Add(item.FilePath);
        }
        Clipboard.SetFileDropList(sc);
    }

    private void Clear_Click(object sender, RoutedEventArgs e)
    {
        Items.Clear();
        UpdateView();
    }

    private void ConvertAll_Click(object sender, RoutedEventArgs e)
    {
        if (Items.Count == 0) return;

        var list = Items.Select(i => i.FilePath).ToList();
        ConvertRequested?.Invoke(list);
    }

    #endregion
}

/// <summary>
/// Model representing an item pinned to the floating drop shelf.
/// </summary>
public class ShelfItem
{
    public string FilePath { get; set; } = string.Empty;
    public string FileName => Path.GetFileName(FilePath);
    public string Extension
    {
        get
        {
            string ext = Path.GetExtension(FilePath).TrimStart('.');
            return string.IsNullOrEmpty(ext) ? (IsDirectory ? "DIR" : "FILE") : ext.ToUpperInvariant();
        }
    }
    public string FormattedSize { get; set; } = string.Empty;
    public ImageSource? IconSource { get; set; }
    public bool IsDirectory { get; set; }

    public static ShelfItem FromPath(string path)
    {
        bool isDir = Directory.Exists(path);
        long size = 0;
        if (!isDir && File.Exists(path))
        {
            try
            {
                size = new FileInfo(path).Length;
            }
            catch { }
        }

        return new ShelfItem
        {
            FilePath = path,
            IsDirectory = isDir,
            FormattedSize = isDir ? "Folder" : FormatSize(size),
            IconSource = GetPathIcon(path)
        };
    }

    private static string FormatSize(long bytes)
    {
        if (bytes < 1024) return $"{bytes} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
        if (bytes < 1024 * 1024 * 1024) return $"{bytes / (1024.0 * 1024.0):F1} MB";
        return $"{bytes / (1024.0 * 1024.0 * 1024.0):F2} GB";
    }

    private static ImageSource? GetPathIcon(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                using var icon = System.Drawing.Icon.ExtractAssociatedIcon(path);
                if (icon != null)
                {
                    var bs = System.Windows.Interop.Imaging.CreateBitmapSourceFromHIcon(
                        icon.Handle,
                        Int32Rect.Empty,
                        BitmapSizeOptions.FromEmptyOptions());
                    bs.Freeze();
                    return bs;
                }
            }
        }
        catch { }
        return null;
    }
}
