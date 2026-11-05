using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using FlowConverter.Windows.Engines;
using FlowConverter.Windows.Models;

namespace FlowConverter.Windows.Views;

public partial class ToolWorkspaceWindow : Window
{
    private readonly FileTool _tool;
    private readonly List<string> _inputFiles;
    private readonly FileToolExecutionOptions _options = new();

    private ThreeMFProjectSummary? _threeMfSummary;
    private ComboBox? _targetPrinterCombo;
    private ComboBox? _preset3MfCombo;
    private CheckBox? _recenter3MfCheck;
    private CheckBox? _preserveFilamentsCheck;

    // Crop UI controls
    private Canvas? _cropOverlayCanvas;
    private System.Windows.Shapes.Rectangle? _cropBoxRect;
    private Point _cropDragStart;
    private bool _isDrawingCrop;

    // Redaction UI controls
    private Canvas? _redactOverlayCanvas;
    private Point _redactDragStart;
    private System.Windows.Shapes.Rectangle? _activeRedactRectShape;
    private bool _isDrawingRedact;

    public ToolWorkspaceWindow(FileTool tool, IReadOnlyList<string> inputFiles)
    {
        InitializeComponent();
        _tool = tool;
        _inputFiles = inputFiles.ToList();

        ToolIconText.Text = _tool.IconGlyph();
        ToolTitleText.Text = _tool.DisplayName();
        ToolSubtitleText.Text = _tool.CenterDescription();
        FileCountBadgeText.Text = $"{_inputFiles.Count} file(s)";
        ExecuteButton.Content = _tool == FileTool.Convert3MF ? "Converter .3MF" : $"Run {_tool.DisplayName()}";

        BuildEditorUI();
    }

    private void BuildEditorUI()
    {
        WorkspaceContentPanel.Children.Clear();

        switch (_tool)
        {
            case FileTool.Convert3MF:
                BuildThreeMfEditor();
                break;

            case FileTool.CropImage:
            case FileTool.CropVideo:
                BuildVisualCropEditor();
                break;

            case FileTool.TrimAudio:
            case FileTool.TrimVideo:
                BuildWaveformTrimEditor();
                break;

            case FileTool.RedactImage:
            case FileTool.RedactVideo:
            case FileTool.RedactAudio:
                BuildRedactionEditor();
                break;

            case FileTool.EditImage:
                BuildImageAdjustmentsEditor();
                break;

            case FileTool.FrameImage:
                BuildFrameImageEditor();
                break;

            case FileTool.CreateCollage:
                BuildCollageEditor();
                break;

            default:
                BuildStandardToolOptionsEditor();
                break;
        }
    }

    // ========================================================================
    // 1. 3MF Inspector & Cross-Printer Converter Editor
    // ========================================================================
    private void BuildThreeMfEditor()
    {
        string firstFile = _inputFiles.FirstOrDefault() ?? "";
        _threeMfSummary = File.Exists(firstFile)
            ? ThreeMFConverterEngine.Inspect(firstFile)
            : new ThreeMFProjectSummary { FileName = System.IO.Path.GetFileName(firstFile) };

        // Project Summary Card
        var inspectCard = CreateSectionCard("Projeto .3MF Original Detectado");
        var topGrid = new Grid { Margin = new Thickness(0, 6, 0, 0) };
        topGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(136) });
        topGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var thumbBorder = new Border
        {
            Width = 120,
            Height = 120,
            CornerRadius = new CornerRadius(10),
            Background = new SolidColorBrush(Color.FromRgb(14, 19, 30)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(42, 54, 79)),
            BorderThickness = new Thickness(1),
            HorizontalAlignment = HorizontalAlignment.Left
        };

        if (_threeMfSummary.ThumbnailBytes != null && _threeMfSummary.ThumbnailBytes.Length > 0)
        {
            try
            {
                var bi = new BitmapImage();
                using (var ms = new MemoryStream(_threeMfSummary.ThumbnailBytes))
                {
                    bi.BeginInit();
                    bi.CacheOption = BitmapCacheOption.OnLoad;
                    bi.StreamSource = ms;
                    bi.EndInit();
                    bi.Freeze();
                }
                thumbBorder.Child = new Image { Source = bi, Stretch = Stretch.Uniform, Margin = new Thickness(4) };
            }
            catch { }
        }
        else
        {
            thumbBorder.Child = new TextBlock
            {
                Text = "🖨 3MF",
                Foreground = new SolidColorBrush(Color.FromRgb(0, 229, 255)),
                FontSize = 18,
                FontWeight = FontWeights.Bold,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
        }
        Grid.SetColumn(thumbBorder, 0);
        topGrid.Children.Add(thumbBorder);

        var metaStack = new StackPanel();
        metaStack.Children.Add(new TextBlock
        {
            Text = $"Impressora Original: {_threeMfSummary.OriginalPrinterName}",
            FontSize = 15,
            FontWeight = FontWeights.Bold,
            Foreground = new SolidColorBrush(Color.FromRgb(0, 229, 255))
        });
        metaStack.Children.Add(new TextBlock
        {
            Text = $"Arquivo: {_threeMfSummary.FileName} · Fatiador: {_threeMfSummary.SlicerApplication}",
            FontSize = 12,
            Foreground = new SolidColorBrush(Color.FromRgb(160, 174, 192)),
            Margin = new Thickness(0, 3, 0, 8)
        });

        var specsWrap = new WrapPanel();
        specsWrap.Children.Add(CreateSpecPill("Mesa", $"{_threeMfSummary.BedWidthMM:0}×{_threeMfSummary.BedDepthMM:0}×{_threeMfSummary.BedHeightMM:0} mm"));
        specsWrap.Children.Add(CreateSpecPill("Bico", $"{_threeMfSummary.NozzleDiameterMM:0.0} mm"));
        specsWrap.Children.Add(CreateSpecPill("Camada", $"{_threeMfSummary.LayerHeightMM:0.00} mm"));
        specsWrap.Children.Add(CreateSpecPill("Paredes", $"{_threeMfSummary.WallLoops}"));
        specsWrap.Children.Add(CreateSpecPill("Infill", _threeMfSummary.InfillDensity));
        specsWrap.Children.Add(CreateSpecPill("Suporte", _threeMfSummary.SupportEnabled ? "Ativado" : "Desativado"));
        specsWrap.Children.Add(CreateSpecPill("Placas / Peças", $"{_threeMfSummary.PlateCount} / {_threeMfSummary.ObjectCount}"));
        if (_threeMfSummary.EstimatedTimeSeconds > 0)
            specsWrap.Children.Add(CreateSpecPill("Tempo Est.", _threeMfSummary.FormattedPrintTime));
        if (_threeMfSummary.TotalWeightGrams > 0)
            specsWrap.Children.Add(CreateSpecPill("Peso", _threeMfSummary.FormattedWeight));

        metaStack.Children.Add(specsWrap);

        if (_threeMfSummary.Filaments.Count > 0)
        {
            var filPanel = new WrapPanel { Margin = new Thickness(0, 8, 0, 0) };
            foreach (var fil in _threeMfSummary.Filaments)
            {
                Color c = Colors.Cyan;
                try { c = (Color)ColorConverter.ConvertFromString(fil.ColorHex); } catch { }
                var badge = new Border
                {
                    Background = new SolidColorBrush(Color.FromRgb(24, 32, 48)),
                    BorderBrush = new SolidColorBrush(c),
                    BorderThickness = new Thickness(1.5),
                    CornerRadius = new CornerRadius(6),
                    Padding = new Thickness(8, 3, 8, 3),
                    Margin = new Thickness(0, 0, 6, 4)
                };
                var sp = new StackPanel { Orientation = Orientation.Horizontal };
                sp.Children.Add(new Ellipse
                {
                    Width = 10, Height = 10,
                    Fill = new SolidColorBrush(c),
                    Margin = new Thickness(0, 0, 6, 0),
                    VerticalAlignment = VerticalAlignment.Center
                });
                sp.Children.Add(new TextBlock
                {
                    Text = $"#{fil.SlotIndex} {fil.FilamentType}",
                    Foreground = Brushes.White,
                    FontSize = 11,
                    FontWeight = FontWeights.SemiBold
                });
                badge.Child = sp;
                filPanel.Children.Add(badge);
            }
            metaStack.Children.Add(filPanel);
        }

        Grid.SetColumn(metaStack, 1);
        topGrid.Children.Add(metaStack);
        ((StackPanel)inspectCard.Child).Children.Add(topGrid);
        WorkspaceContentPanel.Children.Add(inspectCard);

        // Target Printer Selection Card
        var targetCard = CreateSectionCard("Escolha a Impressora 3D de Destino");
        var targetPanel = (StackPanel)targetCard.Child;

        _targetPrinterCombo = new ComboBox
        {
            Height = 36,
            Margin = new Thickness(0, 8, 0, 10),
            FontSize = 13
        };
        RefreshTargetPrinterCombo();
        targetPanel.Children.Add(_targetPrinterCombo);

        // Quick Add Printer from 84-Model Catalog
        var addExpander = new Expander
        {
            Header = "+ Adicionar Impressora do Catálogo (84 Modelos / 12 Marcas)",
            Foreground = new SolidColorBrush(Color.FromRgb(0, 229, 255)),
            Margin = new Thickness(0, 4, 0, 6)
        };
        var addStack = new StackPanel { Margin = new Thickness(0, 8, 0, 4) };
        var brandCombo = new ComboBox { Height = 32, Margin = new Thickness(0, 0, 0, 6) };
        var modelCombo = new ComboBox { Height = 32, Margin = new Thickness(0, 0, 0, 6) };
        foreach (string b in Printer3DModel.ManufacturerList.Where(b => b != "Personalizada"))
            brandCombo.Items.Add(b);
        brandCombo.SelectedIndex = 0;

        void UpdateModelsForBrand()
        {
            modelCombo.Items.Clear();
            string selectedBrand = brandCombo.SelectedItem as string ?? "Anycubic";
            foreach (var m in Printer3DModel.AllPresetModels.Where(x => x.Brand.Equals(selectedBrand, StringComparison.OrdinalIgnoreCase)))
            {
                modelCombo.Items.Add(m);
            }
            modelCombo.DisplayMemberPath = "Name";
            if (modelCombo.Items.Count > 0) modelCombo.SelectedIndex = 0;
        }
        brandCombo.SelectionChanged += (_, _) => UpdateModelsForBrand();
        UpdateModelsForBrand();

        var addBtn = new Button
        {
            Content = "Adicionar e Selecionar Impressora",
            Height = 32,
            Background = new SolidColorBrush(Color.FromRgb(30, 41, 59)),
            Foreground = new SolidColorBrush(Color.FromRgb(0, 229, 255)),
            HorizontalAlignment = HorizontalAlignment.Left,
            Padding = new Thickness(14, 4, 14, 4)
        };
        addBtn.Click += (_, _) =>
        {
            if (modelCombo.SelectedItem is Printer3DModel chosenPreset)
            {
                var list = FlowConverterSettings.Instance.ConfiguredPrinters3D;
                var existing = list.FirstOrDefault(p => p.Name.Equals(chosenPreset.Name, StringComparison.OrdinalIgnoreCase));
                if (existing == null)
                {
                    existing = new Printer3DModel
                    {
                        Brand = chosenPreset.Brand,
                        Name = chosenPreset.Name,
                        ShortWheelName = chosenPreset.ShortWheelName,
                        BedWidthMM = chosenPreset.BedWidthMM,
                        BedDepthMM = chosenPreset.BedDepthMM,
                        BedHeightMM = chosenPreset.BedHeightMM,
                        NozzleDiameterMM = chosenPreset.NozzleDiameterMM,
                        GcodeFlavor = chosenPreset.GcodeFlavor,
                        PrinterSettingsID = chosenPreset.PrinterSettingsID,
                        ShowInWheel = true
                    };
                    list.Add(existing);
                    FlowConverterSettings.Instance.Save();
                }
                RefreshTargetPrinterCombo(existing.Id);
                addExpander.IsExpanded = false;
            }
        };

        addStack.Children.Add(new TextBlock { Text = "Fabricante:", Foreground = Brushes.LightGray, FontSize = 11.5, Margin = new Thickness(0, 0, 0, 2) });
        addStack.Children.Add(brandCombo);
        addStack.Children.Add(new TextBlock { Text = "Modelo:", Foreground = Brushes.LightGray, FontSize = 11.5, Margin = new Thickness(0, 0, 0, 2) });
        addStack.Children.Add(modelCombo);
        addStack.Children.Add(addBtn);
        addExpander.Content = addStack;
        targetPanel.Children.Add(addExpander);
        WorkspaceContentPanel.Children.Add(targetCard);

        // Preset & Options Card
        var optsCard = CreateSectionCard("Perfil de Otimização & Opções .3MF");
        var optsPanel = (StackPanel)optsCard.Child;

        optsPanel.Children.Add(new TextBlock
        {
            Text = "Preset de Impressão:",
            Foreground = Brushes.LightGray,
            FontSize = 12,
            Margin = new Thickness(0, 6, 0, 4)
        });

        _preset3MfCombo = new ComboBox { Height = 34, Margin = new Thickness(0, 0, 0, 12) };
        foreach (ThreeMFOptimizationPreset p in Enum.GetValues<ThreeMFOptimizationPreset>())
        {
            _preset3MfCombo.Items.Add(new ComboBoxItem
            {
                Content = $"{p.DisplayName()} — {p.Description()}",
                Tag = p
            });
        }
        _preset3MfCombo.SelectedIndex = 0;
        optsPanel.Children.Add(_preset3MfCombo);

        _recenter3MfCheck = new CheckBox
        {
            Content = "Recentralizar peças automaticamente na mesa de destino (3D/3dmodel.model)",
            IsChecked = true,
            Foreground = Brushes.White,
            Margin = new Thickness(0, 4, 0, 8)
        };
        _preserveFilamentsCheck = new CheckBox
        {
            Content = "Preservar slots de filamento multicoloridos, temperaturas e ajustes do autor (different_settings_to_system)",
            IsChecked = true,
            Foreground = Brushes.White,
            Margin = new Thickness(0, 0, 0, 4)
        };

        optsPanel.Children.Add(_recenter3MfCheck);
        optsPanel.Children.Add(_preserveFilamentsCheck);

        var dirs = ThreeMFConverterEngine.ProfileBaseDirectories();
        FooterStatusText.Text = dirs.Count > 0
            ? $"Perfis oficiais detectados ({dirs.Count} diretórios Anycubic/Orca)"
            : "Usando perfis embutidos Anycubic/Orca";

        WorkspaceContentPanel.Children.Add(optsCard);
    }

    private void RefreshTargetPrinterCombo(string? selectId = null)
    {
        if (_targetPrinterCombo == null) return;
        _targetPrinterCombo.Items.Clear();
        var printers = FlowConverterSettings.Instance.ConfiguredPrinters3D;
        if (printers.Count == 0)
        {
            FlowConverterSettings.Instance.ResetPrintersToDefault();
            printers = FlowConverterSettings.Instance.ConfiguredPrinters3D;
        }

        int selectedIdx = 0;
        for (int i = 0; i < printers.Count; i++)
        {
            var p = printers[i];
            _targetPrinterCombo.Items.Add(new ComboBoxItem
            {
                Content = $"{p.Brand} — {p.Name} ({p.BedWidthMM:0}×{p.BedDepthMM:0}×{p.BedHeightMM:0} mm · Bico {p.NozzleDiameterMM:0.0}mm)",
                Tag = p
            });
            if (selectId != null && p.Id == selectId)
                selectedIdx = i;
        }
        _targetPrinterCombo.SelectedIndex = selectedIdx;
    }

    // ========================================================================
    // 2. Interactive Visual Crop Editor
    // ========================================================================
    private void BuildVisualCropEditor()
    {
        var card = CreateSectionCard("Interactive Visual Crop Studio (Drag on image to select crop region)");
        var panel = (StackPanel)card.Child;

        var presetRow = new WrapPanel { Margin = new Thickness(0, 8, 0, 10) };
        (string Label, double? Ratio)[] presets =
        {
            ("Free", null), ("1:1 Square", 1.0), ("16:9 Landscape", 16.0 / 9.0),
            ("9:16 Portrait", 9.0 / 16.0), ("4:3 Classic", 4.0 / 3.0), ("3:2 Photo", 3.0 / 2.0)
        };

        foreach (var pr in presets)
        {
            var btn = new Button
            {
                Content = pr.Label,
                Padding = new Thickness(12, 5, 12, 5),
                Margin = new Thickness(0, 0, 8, 6),
                Background = new SolidColorBrush(Color.FromRgb(28, 37, 54)),
                Foreground = Brushes.White
            };
            btn.Click += (_, _) =>
            {
                if (pr.Ratio.HasValue)
                {
                    double r = pr.Ratio.Value;
                    double w = Math.Min(0.8, r >= 1.0 ? 0.8 : 0.8 * r);
                    double h = Math.Min(0.8, r >= 1.0 ? 0.8 / r : 0.8);
                    _options.Crop.NormalizedX = (1.0 - w) * 0.5;
                    _options.Crop.NormalizedY = (1.0 - h) * 0.5;
                    _options.Crop.NormalizedWidth = w;
                    _options.Crop.NormalizedHeight = h;
                }
                else
                {
                    _options.Crop.NormalizedX = 0.05;
                    _options.Crop.NormalizedY = 0.05;
                    _options.Crop.NormalizedWidth = 0.90;
                    _options.Crop.NormalizedHeight = 0.90;
                }
                UpdateCropVisualBox();
            };
            presetRow.Children.Add(btn);
        }
        panel.Children.Add(presetRow);

        _cropOverlayCanvas = new Canvas
        {
            Width = 560,
            Height = 340,
            Background = new SolidColorBrush(Color.FromRgb(12, 16, 24)),
            ClipToBounds = true,
            Cursor = Cursors.Cross,
            Margin = new Thickness(0, 4, 0, 8)
        };

        string firstFile = _inputFiles.FirstOrDefault() ?? "";
        if (File.Exists(firstFile) && _tool == FileTool.CropImage)
        {
            try
            {
                var bi = new BitmapImage();
                bi.BeginInit();
                bi.UriSource = new Uri(firstFile);
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.EndInit();
                var img = new Image
                {
                    Source = bi,
                    Width = 560,
                    Height = 340,
                    Stretch = Stretch.Fill,
                    Opacity = 0.88
                };
                _cropOverlayCanvas.Children.Add(img);
            }
            catch { }
        }

        _cropBoxRect = new System.Windows.Shapes.Rectangle
        {
            Stroke = new SolidColorBrush(Color.FromRgb(0, 229, 255)),
            StrokeThickness = 2.2,
            Fill = new SolidColorBrush(Color.FromArgb(45, 0, 229, 255))
        };
        _cropOverlayCanvas.Children.Add(_cropBoxRect);
        UpdateCropVisualBox();

        _cropOverlayCanvas.MouseLeftButtonDown += (_, e) =>
        {
            _isDrawingCrop = true;
            _cropDragStart = e.GetPosition(_cropOverlayCanvas);
            _cropOverlayCanvas.CaptureMouse();
        };
        _cropOverlayCanvas.MouseMove += (_, e) =>
        {
            if (!_isDrawingCrop) return;
            Point cur = e.GetPosition(_cropOverlayCanvas);
            double x = Math.Clamp(Math.Min(_cropDragStart.X, cur.X) / _cropOverlayCanvas.Width, 0, 0.96);
            double y = Math.Clamp(Math.Min(_cropDragStart.Y, cur.Y) / _cropOverlayCanvas.Height, 0, 0.96);
            double w = Math.Clamp(Math.Abs(cur.X - _cropDragStart.X) / _cropOverlayCanvas.Width, 0.04, 1.0 - x);
            double h = Math.Clamp(Math.Abs(cur.Y - _cropDragStart.Y) / _cropOverlayCanvas.Height, 0.04, 1.0 - y);
            _options.Crop.NormalizedX = x;
            _options.Crop.NormalizedY = y;
            _options.Crop.NormalizedWidth = w;
            _options.Crop.NormalizedHeight = h;
            UpdateCropVisualBox();
        };
        _cropOverlayCanvas.MouseLeftButtonUp += (_, _) =>
        {
            _isDrawingCrop = false;
            _cropOverlayCanvas.ReleaseMouseCapture();
        };

        panel.Children.Add(_cropOverlayCanvas);
        WorkspaceContentPanel.Children.Add(card);
    }

    private void UpdateCropVisualBox()
    {
        if (_cropOverlayCanvas == null || _cropBoxRect == null) return;
        double cw = _cropOverlayCanvas.Width;
        double ch = _cropOverlayCanvas.Height;
        Canvas.SetLeft(_cropBoxRect, _options.Crop.NormalizedX * cw);
        Canvas.SetTop(_cropBoxRect, _options.Crop.NormalizedY * ch);
        _cropBoxRect.Width = Math.Max(12, _options.Crop.NormalizedWidth * cw);
        _cropBoxRect.Height = Math.Max(12, _options.Crop.NormalizedHeight * ch);
        FooterStatusText.Text = $"Crop Area: X={_options.Crop.NormalizedX * 100:0}% Y={_options.Crop.NormalizedY * 100:0}% · W={_options.Crop.NormalizedWidth * 100:0}% H={_options.Crop.NormalizedHeight * 100:0}%";
    }

    // ========================================================================
    // 3. Interactive Audio / Video Waveform Trimmer
    // ========================================================================
    private void BuildWaveformTrimEditor()
    {
        _options.TrimStartSeconds = 0.0;
        _options.TrimEndSeconds = 15.0;

        var card = CreateSectionCard("Waveform Timeline Trimmer");
        var panel = (StackPanel)card.Child;

        var waveCanvas = new Canvas
        {
            Width = 680,
            Height = 120,
            Background = new SolidColorBrush(Color.FromRgb(12, 16, 26)),
            Margin = new Thickness(0, 10, 0, 14)
        };

        var rng = new Random(42);
        for (int i = 0; i < 96; i++)
        {
            double amp = 0.2 + 0.75 * Math.Abs(Math.Sin(i * 0.21)) * (0.5 + 0.5 * rng.NextDouble());
            double barH = Math.Max(8, amp * 96);
            var bar = new System.Windows.Shapes.Rectangle
            {
                Width = 5,
                Height = barH,
                RadiusX = 2,
                RadiusY = 2,
                Fill = new LinearGradientBrush(
                    Color.FromRgb(0, 229, 255),
                    Color.FromRgb(255, 107, 13),
                    90.0)
            };
            Canvas.SetLeft(bar, 10 + i * 6.9);
            Canvas.SetTop(bar, (120 - barH) * 0.5);
            waveCanvas.Children.Add(bar);
        }
        panel.Children.Add(waveCanvas);

        var startLabel = new TextBlock { Text = "Start Time: 0.0 s", Foreground = Brushes.White, Margin = new Thickness(0, 4, 0, 4) };
        var startSlider = new Slider { Minimum = 0, Maximum = 300, Value = 0, Margin = new Thickness(0, 0, 0, 10) };

        var endLabel = new TextBlock { Text = "End Time: 15.0 s", Foreground = Brushes.White, Margin = new Thickness(0, 4, 0, 4) };
        var endSlider = new Slider { Minimum = 0.5, Maximum = 300, Value = 15.0, Margin = new Thickness(0, 0, 0, 10) };

        startSlider.ValueChanged += (_, _) =>
        {
            _options.TrimStartSeconds = startSlider.Value;
            if (_options.TrimEndSeconds <= _options.TrimStartSeconds + 0.2)
            {
                endSlider.Value = _options.TrimStartSeconds + 1.0;
            }
            startLabel.Text = $"Start Time: {_options.TrimStartSeconds:0.00} s";
            FooterStatusText.Text = $"Trim Duration: {Math.Max(0.1, _options.TrimEndSeconds - _options.TrimStartSeconds):0.00} s";
        };
        endSlider.ValueChanged += (_, _) =>
        {
            _options.TrimEndSeconds = Math.Max(startSlider.Value + 0.2, endSlider.Value);
            endLabel.Text = $"End Time: {_options.TrimEndSeconds:0.00} s";
            FooterStatusText.Text = $"Trim Duration: {Math.Max(0.1, _options.TrimEndSeconds - _options.TrimStartSeconds):0.00} s";
        };

        panel.Children.Add(startLabel);
        panel.Children.Add(startSlider);
        panel.Children.Add(endLabel);
        panel.Children.Add(endSlider);

        WorkspaceContentPanel.Children.Add(card);
    }

    // ========================================================================
    // 4. Interactive Visual & Audio Redaction Editor
    // ========================================================================
    private void BuildRedactionEditor()
    {
        var card = CreateSectionCard("Interactive Redaction Studio (Draw boxes on canvas to redact sensitive regions)");
        var panel = (StackPanel)card.Child;

        var styleCombo = new ComboBox { Height = 32, Width = 220, HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 8, 0, 10) };
        styleCombo.Items.Add(new ComboBoxItem { Content = "Solid Black Box", Tag = RedactionStyle.Solid });
        styleCombo.Items.Add(new ComboBoxItem { Content = "Gaussian Blur / Pixelate", Tag = RedactionStyle.Blur });
        styleCombo.SelectedIndex = 0;
        styleCombo.SelectionChanged += (_, _) =>
        {
            if (styleCombo.SelectedItem is ComboBoxItem cbi && cbi.Tag is RedactionStyle st)
                _options.DefaultRedactionStyle = st;
        };
        panel.Children.Add(styleCombo);

        _redactOverlayCanvas = new Canvas
        {
            Width = 560,
            Height = 320,
            Background = new SolidColorBrush(Color.FromRgb(14, 18, 28)),
            ClipToBounds = true,
            Cursor = Cursors.Cross
        };

        string firstFile = _inputFiles.FirstOrDefault() ?? "";
        if (File.Exists(firstFile) && _tool == FileTool.RedactImage)
        {
            try
            {
                var bi = new BitmapImage();
                bi.BeginInit();
                bi.UriSource = new Uri(firstFile);
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.EndInit();
                _redactOverlayCanvas.Children.Add(new Image
                {
                    Source = bi,
                    Width = 560,
                    Height = 320,
                    Stretch = Stretch.Fill
                });
            }
            catch { }
        }

        _redactOverlayCanvas.MouseLeftButtonDown += (_, e) =>
        {
            _isDrawingRedact = true;
            _redactDragStart = e.GetPosition(_redactOverlayCanvas);
            _activeRedactRectShape = new System.Windows.Shapes.Rectangle
            {
                Stroke = new SolidColorBrush(Color.FromRgb(255, 107, 13)),
                StrokeThickness = 2,
                Fill = new SolidColorBrush(Color.FromArgb(190, 0, 0, 0))
            };
            Canvas.SetLeft(_activeRedactRectShape, _redactDragStart.X);
            Canvas.SetTop(_activeRedactRectShape, _redactDragStart.Y);
            _redactOverlayCanvas.Children.Add(_activeRedactRectShape);
            _redactOverlayCanvas.CaptureMouse();
        };

        _redactOverlayCanvas.MouseMove += (_, e) =>
        {
            if (!_isDrawingRedact || _activeRedactRectShape == null) return;
            Point cur = e.GetPosition(_redactOverlayCanvas);
            double x = Math.Min(_redactDragStart.X, cur.X);
            double y = Math.Min(_redactDragStart.Y, cur.Y);
            double w = Math.Max(8, Math.Abs(cur.X - _redactDragStart.X));
            double h = Math.Max(8, Math.Abs(cur.Y - _redactDragStart.Y));
            Canvas.SetLeft(_activeRedactRectShape, x);
            Canvas.SetTop(_activeRedactRectShape, y);
            _activeRedactRectShape.Width = w;
            _activeRedactRectShape.Height = h;
        };

        _redactOverlayCanvas.MouseLeftButtonUp += (_, e) =>
        {
            if (!_isDrawingRedact || _activeRedactRectShape == null) return;
            _isDrawingRedact = false;
            _redactOverlayCanvas.ReleaseMouseCapture();

            double x = Canvas.GetLeft(_activeRedactRectShape) / _redactOverlayCanvas.Width;
            double y = Canvas.GetTop(_activeRedactRectShape) / _redactOverlayCanvas.Height;
            double w = _activeRedactRectShape.Width / _redactOverlayCanvas.Width;
            double h = _activeRedactRectShape.Height / _redactOverlayCanvas.Height;
            _options.RedactionRectangles.Add(new RedactionRectangle
            {
                NormalizedX = Math.Clamp(x, 0, 0.98),
                NormalizedY = Math.Clamp(y, 0, 0.98),
                NormalizedW = Math.Clamp(w, 0.02, 1.0 - x),
                NormalizedH = Math.Clamp(h, 0.02, 1.0 - y),
                Style = _options.DefaultRedactionStyle
            });
            FooterStatusText.Text = $"{_options.RedactionRectangles.Count} redaction region(s) added";
        };

        panel.Children.Add(_redactOverlayCanvas);
        WorkspaceContentPanel.Children.Add(card);
    }

    // ========================================================================
    // 5. Image Adjustments, Frame, Collage & Standard Editors
    // ========================================================================
    private void BuildImageAdjustmentsEditor()
    {
        var card = CreateSectionCard("Image Color & Exposure Adjustments");
        var panel = (StackPanel)card.Child;

        AddSliderControl(panel, "Exposure", -1.0, 1.0, 0.0, v => _options.Adjustments.Exposure = v);
        AddSliderControl(panel, "Brightness", -0.5, 0.5, 0.0, v => _options.Adjustments.Brightness = v);
        AddSliderControl(panel, "Contrast", -0.5, 0.8, 0.0, v => _options.Adjustments.Contrast = v);
        AddSliderControl(panel, "Saturation", -1.0, 1.0, 0.0, v => _options.Adjustments.Saturation = v);

        WorkspaceContentPanel.Children.Add(card);
    }

    private void BuildFrameImageEditor()
    {
        var card = CreateSectionCard("Studio Frame & Gradient Backdrop");
        var panel = (StackPanel)card.Child;

        var combo = new ComboBox { Height = 34, Margin = new Thickness(0, 8, 0, 12) };
        foreach (var preset in FrameBackgroundPreset.AllPresets)
        {
            combo.Items.Add(new ComboBoxItem
            {
                Content = $"{preset.Name} ({preset.StartHex} → {preset.EndHex})",
                Tag = preset
            });
        }
        combo.SelectedIndex = 0;
        combo.SelectionChanged += (_, _) =>
        {
            if (combo.SelectedItem is ComboBoxItem cbi && cbi.Tag is FrameBackgroundPreset p)
                _options.FramePreset = p;
        };
        panel.Children.Add(combo);
        AddSliderControl(panel, "Padding (px)", 16, 160, 48, v => _options.FramePadding = (int)v);

        WorkspaceContentPanel.Children.Add(card);
    }

    private void BuildCollageEditor()
    {
        var card = CreateSectionCard("Photo Grid Collage Options");
        var panel = (StackPanel)card.Child;

        AddSliderControl(panel, "Grid Columns", 1, 6, 2, v => _options.CollageColumns = (int)v);
        AddSliderControl(panel, "Canvas Width (px)", 800, 3840, 1920, v => _options.CollageCanvasWidth = (int)v);
        AddSliderControl(panel, "Cell Spacing (px)", 0, 64, 16, v => _options.CollageSpacing = (int)v);

        WorkspaceContentPanel.Children.Add(card);
    }

    private void BuildStandardToolOptionsEditor()
    {
        var card = CreateSectionCard($"{_tool.DisplayName()} Configuration");
        var panel = (StackPanel)card.Child;

        if (_tool == FileTool.ChangeVideoSpeed)
        {
            AddSliderControl(panel, "Playback Speed Multiplier (x)", 0.25, 4.0, 1.5, v => _options.VideoSpeedMultiplier = v);
        }
        else if (_tool == FileTool.NormalizeAudio)
        {
            AddSliderControl(panel, "Target Loudness (LUFS)", -24.0, -8.0, -14.0, v => _options.TargetLufs = v);
        }
        else if (_tool == FileTool.Compress)
        {
            AddSliderControl(panel, "Max Image Longest Edge (px)", 640, 3840, 1920, v => _options.CompressionMaxEdgePixels = (int)v);
        }
        else
        {
            panel.Children.Add(new TextBlock
            {
                Text = $"Selected {_inputFiles.Count} file(s) for {_tool.DisplayName()}. Click Execute below to run.",
                Foreground = Brushes.LightGray,
                Margin = new Thickness(0, 8, 0, 4)
            });
        }

        WorkspaceContentPanel.Children.Add(card);
    }

    private static void AddSliderControl(StackPanel parent, string title, double min, double max, double initial, Action<double> onChanged)
    {
        var lbl = new TextBlock
        {
            Text = $"{title}: {initial:0.##}",
            Foreground = Brushes.White,
            Margin = new Thickness(0, 6, 0, 4)
        };
        var slider = new Slider
        {
            Minimum = min,
            Maximum = max,
            Value = initial,
            Margin = new Thickness(0, 0, 0, 8)
        };
        slider.ValueChanged += (_, _) =>
        {
            lbl.Text = $"{title}: {slider.Value:0.##}";
            onChanged(slider.Value);
        };
        parent.Children.Add(lbl);
        parent.Children.Add(slider);
    }

    private static Border CreateSectionCard(string heading)
    {
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = heading,
            FontSize = 14,
            FontWeight = FontWeights.Bold,
            Foreground = new SolidColorBrush(Color.FromRgb(0, 229, 255)),
            Margin = new Thickness(0, 0, 0, 6)
        });

        return new Border
        {
            Background = new SolidColorBrush(Color.FromRgb(19, 25, 38)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(36, 46, 68)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(16, 14, 16, 14),
            Margin = new Thickness(0, 0, 0, 14),
            Child = stack
        };
    }

    private static Border CreateSpecPill(string label, string value)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal };
        sp.Children.Add(new TextBlock
        {
            Text = $"{label}: ",
            Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)),
            FontSize = 11
        });
        sp.Children.Add(new TextBlock
        {
            Text = value,
            Foreground = Brushes.White,
            FontSize = 11,
            FontWeight = FontWeights.SemiBold
        });
        return new Border
        {
            Background = new SolidColorBrush(Color.FromRgb(26, 34, 52)),
            CornerRadius = new CornerRadius(5),
            Padding = new Thickness(8, 3, 8, 3),
            Margin = new Thickness(0, 0, 6, 5),
            Child = sp
        };
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        Close();
    }

    private async void OnExecuteClick(object sender, RoutedEventArgs e)
    {
        if (_tool == FileTool.Convert3MF)
        {
            if (_targetPrinterCombo?.SelectedItem is ComboBoxItem cbi && cbi.Tag is Printer3DModel targetPrinter)
            {
                _options.TargetPrinter = targetPrinter;
            }
            if (_preset3MfCombo?.SelectedItem is ComboBoxItem pItem && pItem.Tag is ThreeMFOptimizationPreset preset)
            {
                _options.OptimizationPreset = preset;
            }
            _options.RecenterOnBed = _recenter3MfCheck?.IsChecked != false;
            _options.PreserveFilaments = _preserveFilamentsCheck?.IsChecked != false;
        }

        ExecuteButton.IsEnabled = false;
        var progressWin = new OperationProgressWindow(_tool.DisplayName(), _inputFiles.Count);
        progressWin.Show();

        var outputs = new List<string>();
        var errors = new List<string>();

        await Task.Run(() =>
        {
            try
            {
                outputs = ToolExecutionEngine.ExecuteBatch(
                    _tool,
                    _inputFiles,
                    _options,
                    (prog, msg) => progressWin.UpdateProgress(prog, msg));
            }
            catch (Exception ex)
            {
                errors.Add(ex.Message);
            }
        });

        FlowConverterSettings.Instance.UsageCount += outputs.Count;
        FlowConverterSettings.Instance.Save();

        progressWin.Finish(outputs, errors);
        Close();
    }
}
