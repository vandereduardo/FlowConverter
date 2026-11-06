using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
using FlowConverter.Windows.Interop;
using FlowConverter.Windows.Models;
using FlowConverter.Windows.Services;

namespace FlowConverter.Windows.Views;

public partial class RadialWheelWindow : Window
{
    public sealed class WheelPetalItem
    {
        public string ShortLabel { get; init; } = "";
        public string SubLabel { get; init; } = "";
        public string IconGlyph { get; init; } = "";
        public string CenterDescription { get; init; } = "";
        public ConversionFormat? TargetFormat { get; init; }
        public FileTool? TargetTool { get; init; }
        public Printer3DModel? TargetPrinter3D { get; init; }
        public QuickActionType? TargetQuickAction { get; init; }
    }

    private WheelMode _currentMode = WheelMode.Conversions;
    private List<string> _activeFiles = new();
    private List<WheelPetalItem> _petals = new();
    private int _highlightedIndex = -1;

    public event Action<WheelPetalItem, IReadOnlyList<string>>? PetalSelected;

    public RadialWheelWindow()
    {
        InitializeComponent();
        SourceInitialized += (_, _) =>
        {
            IntPtr hwnd = new WindowInteropHelper(this).Handle;
            NativeMethods.MakeWindowNonActivatingToolWindow(hwnd);
        };
    }

    public WheelMode CurrentMode => _currentMode;

    public void Summon(WheelMode mode, Point cursorDipPoint, IReadOnlyList<string> filePaths)
    {
        _currentMode = mode;
        _activeFiles = filePaths.Where(p => !string.IsNullOrWhiteSpace(p)).ToList();
        _highlightedIndex = -1;

        Left = cursorDipPoint.X - Width * 0.5;
        Top = cursorDipPoint.Y - Height * 0.5;

        RebuildPetals();
        RenderWheel();

        if (!IsVisible)
        {
            Show();
        }
    }

    public void CycleMode()
    {
        _currentMode = _currentMode switch
        {
            WheelMode.Conversions => WheelMode.FileTools,
            WheelMode.FileTools => WheelMode.FileActions,
            _ => WheelMode.Conversions
        };
        _highlightedIndex = -1;
        SoundService.Instance.PlayPetalHighlight();
        RebuildPetals();
        RenderWheel();
    }

    public void UpdateFilesAndRebuild(IReadOnlyList<string> filePaths)
    {
        var cleaned = filePaths.Where(p => !string.IsNullOrWhiteSpace(p)).ToList();
        if (cleaned.Count > 0 && !cleaned.SequenceEqual(_activeFiles, StringComparer.OrdinalIgnoreCase))
        {
            _activeFiles = cleaned;
            RebuildPetals();
            RenderWheel();
        }
    }

    public void UpdateCursorScreenPoint(Point screenDipPoint)
    {
        if (!IsVisible) return;
        Point local = new(screenDipPoint.X - Left, screenDipPoint.Y - Top);
        UpdateHoverAtLocalPoint(local);
    }

    public bool CommitHighlightedIfAny()
    {
        if (!IsVisible || _highlightedIndex < 0 || _highlightedIndex >= _petals.Count)
        {
            Hide();
            return false;
        }

        var chosen = _petals[_highlightedIndex];
        var files = _activeFiles.ToList();
        Hide();
        PetalSelected?.Invoke(chosen, files);
        return true;
    }

    private void RebuildPetals()
    {
        _petals.Clear();
        bool all3mf = _activeFiles.Count > 0 && _activeFiles.All(f => f.EndsWith(".3mf", StringComparison.OrdinalIgnoreCase));

        switch (_currentMode)
        {
            case WheelMode.Conversions:
                if (all3mf)
                {
                    var printers = FlowConverterSettings.Instance.WheelPrinters3D().Take(11).ToList();
                    foreach (var p in printers)
                    {
                        _petals.Add(new WheelPetalItem
                        {
                            ShortLabel = string.IsNullOrWhiteSpace(p.ShortWheelName) ? p.Name : p.ShortWheelName,
                            SubLabel = $"{p.BedWidthMM:0}×{p.BedDepthMM:0}",
                            CenterDescription = $"3MF → {p.Name}",
                            TargetPrinter3D = p
                        });
                    }
                    _petals.Add(new WheelPetalItem
                    {
                        ShortLabel = "3MF Studio",
                        SubLabel = "INSPECT",
                        CenterDescription = "Open 3MF Inspector & Converter",
                        TargetTool = FileTool.Convert3MF
                    });
                }
                else
                {
                    List<ConversionFormat> formats;
                    if (_activeFiles.Count > 0)
                    {
                        formats = ConversionFormatHelper.CommonFormatsForBatch(_activeFiles).Take(12).ToList();
                    }
                    else
                    {
                        formats = new List<ConversionFormat>
                        {
                            ConversionFormat.Jpg, ConversionFormat.Png, ConversionFormat.Webp, ConversionFormat.Pdf,
                            ConversionFormat.Mp4, ConversionFormat.Mp3, ConversionFormat.Gif, ConversionFormat.Zip
                        };
                    }

                    foreach (var fmt in formats)
                    {
                        _petals.Add(new WheelPetalItem
                        {
                            ShortLabel = fmt.DisplayName(),
                            SubLabel = fmt.Category().Title(),
                            CenterDescription = fmt.CenterDescription(),
                            TargetFormat = fmt
                        });
                    }
                }
                break;

            case WheelMode.FileTools:
            {
                List<FileTool> tools;
                if (_activeFiles.Count > 0)
                {
                    tools = FileToolExtensions.CompatibleTools(_activeFiles).Take(12).ToList();
                }
                else
                {
                    tools = new List<FileTool>
                    {
                        FileTool.Convert3MF, FileTool.Compress, FileTool.RemoveMetadata, FileTool.CropImage,
                        FileTool.EditImage, FileTool.FrameImage, FileTool.RedactImage, FileTool.TrimAudio,
                        FileTool.AudioToVideo, FileTool.MergePDF, FileTool.ReadQRCode, FileTool.CreateArchive
                    };
                }

                foreach (var tool in tools)
                {
                    _petals.Add(new WheelPetalItem
                    {
                        ShortLabel = tool.ShortWheelLabel(),
                        IconGlyph = tool.IconGlyph(),
                        CenterDescription = tool.CenterDescription(),
                        TargetTool = tool
                    });
                }
                break;
            }

            case WheelMode.FileActions:
            {
                foreach (QuickActionType act in Enum.GetValues<QuickActionType>())
                {
                    _petals.Add(new WheelPetalItem
                    {
                        ShortLabel = act.DisplayName(),
                        IconGlyph = act.IconGlyph(),
                        CenterDescription = act.CenterDescription(),
                        TargetQuickAction = act
                    });
                }
                break;
            }
        }
    }

    private static readonly FontFamily WheelIconFont = new("Segoe MDL2 Assets");

    private void RenderWheel()
    {
        PetalsCanvas.Children.Clear();
        int count = Math.Max(_petals.Count, 1);

        const double cx = 180.0;
        const double cy = 180.0;
        const double innerR = 58.0;
        const double baseOuterR = 158.0;
        const double activeOuterR = 166.0;
        const double gapDegrees = 2.0;

        bool metallic = FlowConverterSettings.Instance.Theme == ConversionFanTheme.Metallic;
        double stepDeg = 360.0 / count;

        for (int i = 0; i < _petals.Count; i++)
        {
            bool isHighlighted = i == _highlightedIndex;
            double outerR = isHighlighted ? activeOuterR : baseOuterR;
            double labelR = isHighlighted ? 112.0 : 108.0;

            double centerDeg = -90.0 + i * stepDeg;
            double startDeg = centerDeg - (stepDeg - gapDegrees) * 0.5;
            double endDeg = centerDeg + (stepDeg - gapDegrees) * 0.5;

            var geom = CreateAnnularSectorGeometry(cx, cy, innerR, outerR, startDeg, endDeg);
            var path = new System.Windows.Shapes.Path
            {
                Data = geom,
                StrokeThickness = isHighlighted ? 2.2 : 1.1
            };

            if (isHighlighted)
            {
                path.Fill = new LinearGradientBrush(
                    Color.FromArgb(248, 255, 107, 13),
                    Color.FromArgb(248, 230, 66, 0),
                    45.0);
                path.Stroke = new SolidColorBrush(Color.FromArgb(255, 255, 185, 120));
            }
            else if (metallic)
            {
                path.Fill = new LinearGradientBrush(
                    Color.FromArgb(238, 71, 74, 84),
                    Color.FromArgb(242, 34, 37, 45),
                    45.0);
                path.Stroke = new SolidColorBrush(Color.FromArgb(115, 0, 229, 255));
            }
            else
            {
                path.Fill = new LinearGradientBrush(
                    Color.FromArgb(204, 56, 58, 68),
                    Color.FromArgb(218, 25, 27, 34),
                    45.0);
                path.Stroke = new SolidColorBrush(Color.FromArgb(75, 255, 255, 255));
            }

            PetalsCanvas.Children.Add(path);

            double rad = centerDeg * Math.PI / 180.0;
            double lx = cx + labelR * Math.Cos(rad);
            double ly = cy + labelR * Math.Sin(rad);

            var labelStack = new StackPanel
            {
                Width = 76,
                IsHitTestVisible = false
            };

            var petal = _petals[i];
            bool hasIcon = !string.IsNullOrEmpty(petal.IconGlyph);
            string caption = hasIcon ? petal.IconGlyph : petal.SubLabel;
            if (!string.IsNullOrWhiteSpace(caption))
            {
                labelStack.Children.Add(new TextBlock
                {
                    Text = caption,
                    FontFamily = hasIcon ? WheelIconFont : FontFamily,
                    Foreground = isHighlighted
                        ? Brushes.White
                        : new SolidColorBrush(Color.FromArgb(190, 0, 229, 255)),
                    FontSize = hasIcon ? 15.0 : 9.0,
                    FontWeight = hasIcon ? FontWeights.Normal : FontWeights.SemiBold,
                    TextAlignment = TextAlignment.Center,
                    TextTrimming = TextTrimming.CharacterEllipsis
                });
            }

            labelStack.Children.Add(new TextBlock
            {
                Text = petal.ShortLabel,
                Foreground = Brushes.White,
                FontSize = isHighlighted ? 11.5 : 10.5,
                FontWeight = FontWeights.Bold,
                TextAlignment = TextAlignment.Center,
                TextWrapping = TextWrapping.Wrap
            });

            labelStack.Measure(new Size(76, 60));
            Size desired = labelStack.DesiredSize;
            Canvas.SetLeft(labelStack, lx - 38.0);
            Canvas.SetTop(labelStack, ly - desired.Height * 0.5);
            PetalsCanvas.Children.Add(labelStack);
        }

        HubModeText.Text = _currentMode switch
        {
            WheelMode.Conversions => "CONVERT",
            WheelMode.FileTools => "TOOLS",
            _ => "ACTIONS"
        };

        if (_highlightedIndex >= 0 && _highlightedIndex < _petals.Count)
        {
            HubDescriptionText.Text = _petals[_highlightedIndex].CenterDescription;
        }
        else
        {
            bool all3mf = _activeFiles.Count > 0 && _activeFiles.All(f => f.EndsWith(".3mf", StringComparison.OrdinalIgnoreCase));
            HubDescriptionText.Text = all3mf
                ? "Choose 3D Printer"
                : _currentMode switch
                {
                    WheelMode.Conversions => "Choose Format",
                    WheelMode.FileTools => "Select File Tool",
                    _ => "Quick Actions"
                };
        }

        HubSubtleText.Text = _activeFiles.Count > 0
            ? $"{_activeFiles.Count} item(s) · Hub=Mode"
            : "Click Hub for Mode";
    }

    private void UpdateHoverAtLocalPoint(Point pt)
    {
        double dx = pt.X - 180.0;
        double dy = pt.Y - 180.0;
        double dist = Math.Sqrt(dx * dx + dy * dy);

        int newIndex = -1;
        if (dist >= 50.0 && dist <= 176.0 && _petals.Count > 0)
        {
            double angleDeg = Math.Atan2(dy, dx) * 180.0 / Math.PI;
            double normalized = angleDeg + 90.0 + (180.0 / _petals.Count);
            while (normalized < 0) normalized += 360.0;
            while (normalized >= 360.0) normalized -= 360.0;
            newIndex = (int)Math.Floor(normalized / (360.0 / _petals.Count)) % _petals.Count;
        }

        if (newIndex != _highlightedIndex)
        {
            _highlightedIndex = newIndex;
            if (_highlightedIndex >= 0)
            {
                SoundService.Instance.PlayPetalHighlight();
            }
            RenderWheel();
        }
    }

    private static StreamGeometry CreateAnnularSectorGeometry(
        double cx, double cy, double innerR, double outerR, double startDeg, double endDeg)
    {
        double startRad = startDeg * Math.PI / 180.0;
        double endRad = endDeg * Math.PI / 180.0;
        bool isLargeArc = (endDeg - startDeg) > 180.0;

        Point p1 = new(cx + outerR * Math.Cos(startRad), cy + outerR * Math.Sin(startRad));
        Point p2 = new(cx + outerR * Math.Cos(endRad), cy + outerR * Math.Sin(endRad));
        Point p3 = new(cx + innerR * Math.Cos(endRad), cy + innerR * Math.Sin(endRad));
        Point p4 = new(cx + innerR * Math.Cos(startRad), cy + innerR * Math.Sin(startRad));

        var geom = new StreamGeometry();
        using (var ctx = geom.Open())
        {
            ctx.BeginFigure(p1, isFilled: true, isClosed: true);
            ctx.ArcTo(p2, new Size(outerR, outerR), 0, isLargeArc, SweepDirection.Clockwise, isStroked: true, isSmoothJoin: true);
            ctx.LineTo(p3, isStroked: true, isSmoothJoin: true);
            ctx.ArcTo(p4, new Size(innerR, innerR), 0, isLargeArc, SweepDirection.Counterclockwise, isStroked: true, isSmoothJoin: true);
        }
        geom.Freeze();
        return geom;
    }

    private void OnWindowDragEnter(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            e.Effects = DragDropEffects.Copy;
            if (e.Data.GetData(DataFormats.FileDrop) is string[] files && files.Length > 0)
            {
                UpdateFilesAndRebuild(files);
            }
        }
        e.Handled = true;
    }

    private void OnWindowDragOver(object sender, DragEventArgs e)
    {
        e.Effects = DragDropEffects.Copy;
        UpdateHoverAtLocalPoint(e.GetPosition(this));
        e.Handled = true;
    }

    private void OnWindowDragLeave(object sender, DragEventArgs e)
    {
        _highlightedIndex = -1;
        RenderWheel();
    }

    private void OnWindowDrop(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop) &&
            e.Data.GetData(DataFormats.FileDrop) is string[] files &&
            files.Length > 0)
        {
            _activeFiles = files.ToList();
        }
        UpdateHoverAtLocalPoint(e.GetPosition(this));
        CommitHighlightedIfAny();
        e.Handled = true;
    }

    private void OnWindowMouseMove(object sender, MouseEventArgs e)
    {
        UpdateHoverAtLocalPoint(e.GetPosition(this));
    }

    private void OnWindowMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        Point pt = e.GetPosition(this);
        double dx = pt.X - 180.0;
        double dy = pt.Y - 180.0;
        double dist = Math.Sqrt(dx * dx + dy * dy);

        if (dist < 52.0)
        {
            CycleMode();
            return;
        }

        UpdateHoverAtLocalPoint(pt);
        if (_highlightedIndex >= 0)
        {
            CommitHighlightedIfAny();
        }
        else if (dist > 176.0)
        {
            Hide();
        }
    }

    private void OnWindowKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Hide();
        }
    }
}
