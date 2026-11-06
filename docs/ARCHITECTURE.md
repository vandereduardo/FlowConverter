# FlowConverter Clean-Room Architecture

## 1. Overview & Clean-Room Principles

**FlowConverter** (`Flow Converter`) is a fast, 100% clean-room open-source (MIT License) desktop utility implemented natively for **macOS** and **Windows**.

### Clean-Room Engineering Rules
1. **Zero Proprietary Code & Binaries:** No reverse-engineered source code, proprietary header files, or closed-source third-party binaries from commercial radial tools are used.
2. **Procedural Asset Generation:**
   - The macOS icon artwork is generated with CoreGraphics. Windows embeds PNG frames from that same `AppIcon.icns` in `AppIcon.ico`.
   - Audio feedback (`HighlightSound.wav`) is synthesized mathematically from pure sine waves (a dual-harmonic chime combining `1046.5 Hz` C6 and `1567.98 Hz` G6 with exponential amplitude decay over 55 milliseconds at `44.1 kHz`, 16-bit mono PCM).
3. **Local-Only Processing:** Zero telemetry, cloud dependencies, or external network requests. All conversions and tools execute entirely on the local machine.

---

## 2. Multi-Platform Architectural Stack

FlowConverter provides identical domain models, visual design languages, conversion capabilities, and 3D printing profile engines across both operating systems while taking full advantage of each platform's native frameworks:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          FlowConverter Shared Logic                     │
│  - 46 Conversion Formats across 7 Groups                               │
│  - 29 Contextual File Utilities & Visual Editors                       │
│  - 84-Model 3D Printer Catalog across 12 Brands + Custom                │
│  - Slicer Profile Inheritance (.3MF) & Bed Recentering Engine          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         ▼                                                     ▼
┌─────────────────────────────────┐   ┌──────────────────────────────────┐
│        macOS Native App         │   │       Windows Native App         │
│  (Swift 5.9 / AppKit / SwiftUI) │   │     (.NET 8.0 / C# 12 / WPF)     │
├─────────────────────────────────┤   ├──────────────────────────────────┤
│ • Windowing: NSPanel (Non-Act)  │   │ • Windowing: WS_EX_NOACTIVATE    │
│ • UI: SwiftUI + CoreGraphics    │   │ • UI: WPF XAML + DirectWrite     │
│ • Drag: CGEventTap / NSEvent    │   │ • Drag: WH_MOUSE_LL / KEYBOARD_LL│
│ • Tray: NSStatusItem (Menu Bar) │   │ • Tray: NotifyIcon (System Tray) │
│ • Imaging: ImageIO / CoreImage  │   │ • Imaging: WIC / System.Drawing  │
│ • Video: AVFoundation (VTBox)   │   │ • Video: DirectShow / FFmpeg CLI │
│ • Audio: NSSound / AudioToolbox │   │ • Audio: System.Media.SoundPlayer│
│ • PDF: PDFKit                   │   │ • PDF: Native Stream / PDF Raster│
│ • Office: flow_office_converter │   │ • Office: flow_office_converter  │
└─────────────────────────────────┘   └──────────────────────────────────┘
```

---

## 3. Side-by-Side Module Comparison Matrix

The codebase maintains strict conceptual parity between the `macos/` and `windows/` implementations:

| Subsystem | macOS Module (`macos/Sources/FlowConverter/`) | Windows Module (`windows/src/FlowConverter.Windows/`) | Shared Domain Role & Behavior |
| :--- | :--- | :--- | :--- |
| **Application Lifecycle** | `AppDelegate.swift` | `App.xaml` / `App.xaml.cs` | Single-instance lock (`NSRunningApplication` / `Mutex`), CLI parameter parsing, global state coordination, tray management. |
| **Domain Models** | `Models.swift` | `Models/ConversionModels.cs`<br>`Models/FileToolModels.cs`<br>`Models/Printer3DModels.cs`<br>`Models/SettingsModel.cs` | Defines all 46 formats, 7 format groups, 29 file tools, 84 3D printer hardware specs, and user configuration. |
| **Radial Wheel Window** | `RadialWheelOverlay.swift` | `Views/RadialWheelWindow.xaml`<br>`Views/RadialWheelWindow.xaml.cs` | `360×360` borderless, transparent, non-activating floating window. On Windows, light petals have neutral edges, a 2° gap, and an orange active state. Tools and Actions icons use Segoe MDL2 Assets. |
| **Global Drag Monitor** | `AppDelegate.swift` (`NSEvent.addGlobalMonitorForEvents` & `CGEventTap`) | `Interop/DragGestureMonitor.cs`<br>`Interop/NativeMethods.cs` (`WH_MOUSE_LL`, `WH_KEYBOARD_LL`) | Low-level detection of file drag operations while holding trigger modifiers (`Alt`, `Shift`, `Ctrl`) without stealing focus. |
| **Floating Drop Shelf** | `FloatingShelfWindow.swift` | `Views/FloatingShelfWindow.xaml`<br>`Views/FloatingShelfWindow.xaml.cs` | Translucent obsidian glass panel for holding files. Supports drag-in/drag-out, compact/expanded modes, and batch conversion trigger. |
| **Conversion Engine** | `ConversionEngine.swift` | `Engines/UniversalConversionEngine.cs` | Format conversion pipeline routing images, documents, audio, video, archives, and subtitles. |
| **Tool Execution Engine**| `ToolExecutionEngine.swift` | `Engines/ToolExecutionEngine.cs` | Batch executor for media redaction, audio trimming, collage generation, PDF merging/splitting, and QR processing. |
| **3D Printer .3MF Engine**| `ToolExecutionEngine.swift` (`ThreeMFConverterEngine`) | `Engines/ThreeMFConverterEngine.cs` | Slicer profile inheritance walking, multi-color slot translation, project override preservation, and bed geometry recentering. |
| **Interactive Studio** | `ToolWorkspaceWindow.swift` | `Views/ToolWorkspaceWindow.xaml`<br>`Views/ToolWorkspaceWindow.xaml.cs` | Visual workspace for audio waveform editing, video/image redaction, aspect-ratio cropping, QR generation, and 3MF inspection. |
| **Audio Trimmer** | `AudioWaveformTrimView` | `Views/AudioTrimEditor.xaml`<br>`Engines/AudioTrimEngine.cs` | Windows derives timeline peaks and duration from decoded PCM. Preview and export share the selected range and optional per-file detection of silence at the edges. |
| **Preferences & Settings**| `SettingsWindow.swift` | `Models/SettingsModel.cs`<br>`Views/SettingsWindow.xaml` | 7-tab configuration store persisted to JSON (`settings.json`). Windows Settings uses application-level dark templates for text inputs and dropdowns and a window-level template for checkboxes. |
| **Acoustic Feedback** | `AppDelegate.swift` / `NSSound` | `Services/SoundService.cs`<br>`Services/AssetGenerator.cs` | Synthesizes and plays clean-room `HighlightSound.wav` (C6+G6 55ms chime) on petal mouse hover. |
| **System Tray / Menu** | `AppDelegate.swift` (`NSStatusItem`) | `Services/TrayIconService.cs` (`NotifyIcon`) | Desktop tray icon providing quick wheel summon actions, 3MF studio launch, floating shelf creation, and settings access. |

Windows binds each Explorer drag to its source window and rebuilds the wheel before choosing an action when the drop payload changes. File arguments passed to the executable supply the initial wheel context.

Windows saves the interface language in `AppLanguage` and loads it before building the WPF windows or tray menu. WPF text and formatted messages share the embedded `Localization/Strings.json` catalog. English provides the default and fallback. Applying a change on the next launch keeps all windows and menus in the same language.

The Windows image crop editor fits its canvas to the source pixel dimensions. It stores the selection as normalized coordinates and applies the selected aspect ratio to the pixel bounds of each exported image.

The Windows image adjustment editor updates a thumbnail as sliders move and shares the same color transform with the full-resolution export.

Windows application screens use shared WPF brushes and control templates from `App.xaml`. Programmatically drawn editor controls and the tray menu read the same palette. The radial wheel has its own light palette for contrast over the desktop.

Windows photo redaction shares the crop editor's fitted image canvas. Selections are clipped to the preview bounds and their normalized edges are mapped to the source pixels on export.

---

## 4. Deep Dive: .3MF Slicer Profile Inheritance & Sanitization Pipeline

The `.3MF` (3D Manufacturing Format) profile converter transforms 3D slicer project files between different printer models and slicer dialects (AnycubicSlicerNext, OrcaSlicer, Bambu Studio) without losing the user's slicing intent or multi-color filament configuration.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Input .3MF Slicer Archive                       │
│  - [Content_Types].xml                                                 │
│  - 3D/3dmodel.model (Mesh objects & build items)                       │
│  - Metadata/project_settings.config (Slicer & process parameters)       │
│  - Metadata/model_settings.config (Object-specific settings)           │
│  - Metadata/slice_info.config (Plate & filament mapping)               │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 1. Profile Discovery & Slicer Inheritance Walking                      │
│    Scans local slicer paths (Program Files / AppData / Resources)      │
│    Recursively resolves: Vendor Base JSON ➔ Model JSON ➔ Process JSON   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 2. Project Intent & Override Preservation                              │
│    Reads "different_settings_to_system" in project_settings.config     │
│    Extracts user overrides (layer height, walls, infill, speeds, brim) │
│    Preserves multi-color slots (filament_colour, type, purge matrix)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 3. Cross-Slicer Schema Sanitization                                    │
│    - Normalizes boolean types ("true"/"false" vs "1"/"0")              │
│    - De-duplicates scalar keys (enable_overhang_speed, nozzle_type)   │
│    - Reconfigures bed shape & printable volume limits                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 4. 3D Model Geometry & Bed Auto-Recentering                            │
│    Parses 3D/3dmodel.model vertices & object transforms                │
│    Computes bounding box: ΔX = (W_target - W_orig)/2                   │
│    Updates build item translation matrices                             │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Target Output .3MF Archive                      │
│  - Repackaged with standard ZIP compression (Deflate)                  │
│  - Validated for direct loading into target printer slicer             │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Slicer Profile Discovery Locations
Both the macOS and Windows engines search local system directories for official slicer definitions:

- **Windows Search Paths:**
  1. `<AppDirectory>\Resources\profiles\` (Application bundled profiles)
  2. `C:\Program Files\AnycubicSlicerNext\resources\profiles\`
  3. `%APPDATA%\AnycubicSlicerNext\system\`
  4. `C:\Program Files\OrcaSlicer\resources\profiles\`
  5. `%APPDATA%\OrcaSlicer\system\`
  6. `C:\Program Files\Bambu Studio\resources\profiles\`

- **macOS Search Paths:**
  1. `<AppBundle>/Contents/Resources/profiles/`
  2. `/Applications/AnycubicSlicerNext.app/Contents/Resources/profiles/`
  3. `~/Library/Application Support/AnycubicSlicerNext/`
  4. `/Applications/OrcaSlicer.app/Contents/Resources/profiles/`
  5. `~/Library/Application Support/OrcaSlicer/`
  6. `/Applications/BambuStudio.app/Contents/Resources/profiles/`

### 4.2 Recursive Inheritance Resolution
Slicer configurations are arranged in inheritance trees:
- An Anycubic Kobra 3 profile inherits from `Anycubic Kobra 3 0.4 nozzle.json`, which inherits from `fdm_anycubic_common.json`, which inherits from `fdm_printer_common.json`.
- The engine navigates the `"inherits"` property recursively, building a composite configuration table of defaults before applying project-specific overrides.

### 4.3 Preserved Project Intent Keys
The following key groups in `Metadata/project_settings.config` are preserved from the original user project and mapped onto the destination printer profile:

- **Layer & Geometry:** `layer_height`, `initial_layer_print_height`, `wall_loops`, `top_shell_layers`, `bottom_shell_layers`, `top_shell_thickness`, `bottom_shell_thickness`.
- **Infill:** `sparse_infill_density`, `sparse_infill_pattern`, `top_surface_pattern`, `bottom_surface_pattern`, `infill_direction`, `infill_wall_overlap`.
- **Speeds & Accelerations:** `inner_wall_speed`, `outer_wall_speed`, `sparse_infill_speed`, `initial_layer_speed`, `bridge_speed`, `gap_infill_speed`, `small_perimeter_speed`, `overhang_1_4_speed` through `overhang_4_4_speed`.
- **Support Structures:** `enable_support`, `support_type`, `support_style`, `support_on_build_plate_only`, `support_threshold_angle`, `tree_support_branch_angle`, `tree_support_branch_diameter`.
- **Adhesion & Purge:** `brim_type`, `brim_width`, `skirt_loops`, `enable_prime_tower`, `prime_tower_width`, `wipe_tower_no_sparse_layers`, `flush_into_infill`.
- **Special Modes:** `fuzzy_skin`, `spiral_mode` (vase mode), `ironing_type`, `detect_thin_wall`.

### 4.4 Multi-Color Filament Mapping
When converting multi-color projects (e.g. Anycubic ACE Pro or Bambu Lab AMS):
1. Reads `filament_colour`, `filament_type`, and temperatures from `Metadata/project_settings.config`.
2. Inspects `Metadata/slice_info.config` and `Metadata/model_settings.config` to maintain per-object and per-triangle filament slot assignments.
3. Automatically maps purge volumes and flush matrices to match the target printer's filament feed configuration.

### 4.5 Geometry & Bed Auto-Recentering
When converting between printers with different bed dimensions (e.g., from an Anycubic Kobra 3 Max `420×420 mm` to an Anycubic Kobra X `260×260 mm`, or from a Bambu Lab X1C `256×256 mm` to an Anycubic Kobra 3 `250×250 mm`):
1. **XML Parsing:** Parses `3D/3dmodel.model` using XML DOM/XPath to find `<object>` geometries and `<builditem>` elements.
2. **Bounding Box Calculation:** Computes the composite bounding box $(X_{min}, Y_{min}, X_{max}, Y_{max})$ of all meshes across active build plates.
3. **Offset Computation:** Computes the shift required to center the objects on the destination bed:
   $$\Delta X = \frac{\text{BedWidth}_{\text{target}} - \text{BedWidth}_{\text{source}}}{2}$$
   $$\Delta Y = \frac{\text{BedDepth}_{\text{target}} - \text{BedDepth}_{\text{source}}}{2}$$
4. **Transform Matrix Update:** Modifies the 3D affine transformation matrix of each `<builditem transform="m00 m01 m02 m10 m11 m12 m20 m21 m22 tx ty tz">` to translate $(t_x, t_y)$ by $(\Delta X, \Delta Y)$.
5. **Boundary Validation:** Checks whether the scaled model exceeds the target printable volume, warning the user if dimensions exceed target limits.

---

## 5. Security, Sandboxing & Zero Telemetry

- **No Remote Telemetry:** FlowConverter does not send analytics, telemetry, or crash reports to remote endpoints.
- **Local File System Scope:** File modifications occur strictly on files explicitly dragged into the radial wheel or floating shelf, or selected via file picker dialogs.
- **Process Isolation:** CLI conversions (`ffmpeg`, `cwebp`, `flow_office_converter.py`) execute within isolated sub-processes with standard output and error redirection.
- **FFmpeg Setup on Windows:** Settings and media preflight share a setup dialog, and Welcome links to the Settings section when FFmpeg is absent. The installer verifies the provider's SHA-256 and tests the executable before moving it into the per-user tools directory. Resolution checks the validated user selection and managed location before the application tools directory, PATH, and WinGet, so pending operations can continue in the same process.
- **Clean-Room License:** Released under the permissive [MIT License](../LICENSE).
