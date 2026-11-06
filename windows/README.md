# FlowConverter for Windows (.NET 8 / WPF / Win32 Interop)

**FlowConverter for Windows** is a high-performance, 100% clean-room native Windows implementation of FlowConverter. It brings the fluid "cockpit radial wheel" file workflow, floating drop shelf, interactive visual media studio, and cross-slicer 3D printer `.3MF` profile converter to **Windows 10 and Windows 11**.

Built using **.NET 8 (`net8.0-windows`)**, **WPF**, and low-level **Win32 Interop**, FlowConverter achieves complete feature parity with the macOS implementation while adhering to Windows design standards and system integration best practices.

---

## 🎯 Feature Parity Matrix with macOS

| Feature Area | macOS Implementation | Windows Implementation | Parity Status |
| :--- | :--- | :--- | :---: |
| **Supported Formats** | 46 formats (7 categories) | 46 formats (7 categories) | 100% |
| **Contextual File Tools** | 29 tools | 29 tools | 100% |
| **3D Printer Catalog** | 84 models across 12 brands + custom | 84 models across 12 brands + custom | 100% |
| **Radial Wheel Overlay** | `360×360` borderless `NSPanel` | `360×360` layered `WS_EX_NOACTIVATE` WPF window with narrow petal gaps and native Tools and Actions icons | 100% |
| **Wheel Modes** | Conversions, File Tools, Quick Actions | Conversions, File Tools, Quick Actions | 100% |
| **Center Hub Interaction** | Click cycles modes, hover shows details | Click cycles modes, hover shows details | 100% |
| **Floating Drop Shelf** | Compact (`96×112`) & Expanded (`280×320`) | Compact (`96×112`) & Expanded (`280×320`) | 100% |
| **Interactive Tool Studio** | SwiftUI / AppKit interactive canvases | WPF interactive vector canvases & sliders | 100% |
| **Settings Window** | 7-tab sidebar navigation | 7-tab sidebar navigation with dark inputs, dropdowns, and checkboxes | 100% |
| **Audio Feedback** | 44.1 kHz harmonic C6+G6 chime | 44.1 kHz harmonic C6+G6 chime | 100% |
| **Visual Themes** | `Glass` & `Metallic` obsidian surfaces | `Glass` & `Metallic` obsidian surfaces | 100% |
| **Headless CLI Mode** | CLI flags for inspection and conversion | `--inspect-3mf` and `--convert-3mf` CLI flags | 100% |
| **System Integration** | macOS Menu Bar Status Item | Windows Notification Area (System Tray `NotifyIcon`) | 100% |

---

## 🏗️ Architecture & Module Breakdown

The Windows implementation resides under `windows/src/FlowConverter.Windows/` and is divided into five modular layers:

```text
windows/src/FlowConverter.Windows/
├── App.xaml / App.xaml.cs          # Application lifecycle, single-instance mutex, CLI routing
├── Models/                         # Core domain models and configuration
│   ├── ConversionModels.cs         # 46 formats, 7 format groups, conversion options
│   ├── FileToolModels.cs           # 29 tools, tool options, crop & redaction models
│   ├── Printer3DModels.cs          # 84 3D printer models, bed dimensions, gcode flavors
│   └── SettingsModel.cs            # Persistent settings (%APPDATA%\FlowConverter\settings.json)
├── Interop/                        # Win32 APIs and low-level system monitors
│   ├── NativeMethods.cs            # P/Invoke declarations (User32, Shell32, Gdi32)
│   └── DragGestureMonitor.cs       # Low-level hooks (WH_MOUSE_LL, WH_KEYBOARD_LL) & DPI conversion
├── Services/                       # Application services and procedural asset synthesis
│   ├── AssetGenerator.cs           # Procedural generator for HighlightSound.wav and AppIcon.ico
│   ├── SoundService.cs             # Thread-safe acoustic chime player (System.Media.SoundPlayer)
│   └── TrayIconService.cs          # System tray icon, menus, and balloon notifications
├── Engines/                        # Conversion, tool processing, and 3MF engines
│   ├── UniversalConversionEngine.cs# 46-format conversion pipelines (WIC, GDI+, ffmpeg, cwebp, Python)
│   ├── ToolExecutionEngine.cs      # Batch execution router for all 29 file tools
│   └── ThreeMFConverterEngine.cs   # Deep .3MF slicer profile converter & bed recentering engine
└── Views/                          # WPF User Interfaces & Windows
    ├── RadialWheelWindow.xaml      # Cockpit radial wheel overlay (360×360, non-activating)
    ├── FloatingShelfWindow.xaml    # Floating drop shelf (Compact/Expanded, drag-in/drag-out)
    ├── ToolWorkspaceWindow.xaml    # Interactive visual studio (Crop, Trim, Redact, QR, 3MF Inspector)
    ├── OperationProgressWindow.xaml# Batch conversion progress dialog with cancellation
    └── WelcomeWindow.xaml          # First-run welcome and gesture tutorial dialog
```

### 1. `Models/`
- **`ConversionModels.cs`**: Declares the `ConversionFormat` enum with all 46 formats across 7 groups:
  - **Images (8):** JPG, PNG, WebP, HEIC, TIFF, SVG, AVIF, BMP.
  - **Documents (12):** PDF, DOCX, Pages, PPT, PPTX, TXT, MD, RTF, RTFD, TextClipping, HTML, EPUB.
  - **Spreadsheets (5):** XLSX, XLS, ODS, CSV, TSV.
  - **Audio (8):** MP3, M4A, WAV, FLAC, OGG, OPUS, AIFF, WMA.
  - **Video (7):** MP4, MOV, MKV, WebM, AVI, WMV, GIF.
  - **Subtitles (2):** SRT, VTT.
  - **Archives (4):** ZIP, TAR, GZIP, RAR.
  Provides `ConversionOptions` for quality, resolution, format filtering, and target directory resolution.
- **`FileToolModels.cs`**: Declares the `FileTool` enum with all 29 context-aware utilities, along with supporting data structures such as `CropRectModel`, `RedactBoxModel`, `AudioWaveformModel`, and `FileToolExecutionOptions`.
- **`Printer3DModels.cs`**: Contains the full hardware catalog of 84 pre-configured 3D printer profiles across 12 manufacturers (Anycubic, Bambu Lab, Creality, Flashforge, Elegoo, Prusa, Qidi Tech, Sovol, Artillery, Flsun, Voron, Two Trees) plus user-defined custom printers. Stores bed dimensions (`BedWidthMM`, `BedDepthMM`, `BedHeightMM`), nozzle diameters, G-code flavors (`klipper`, `marlin`, `reprapfirmware`), and slicer identifier tags.
- **`SettingsModel.cs`**: Manages global user configuration with JSON persistence at `%APPDATA%\FlowConverter\settings.json`. Covers themes (`Glass`, `Metallic`), modifier key bindings, default output formats, compression presets, watched folders, and first-run flags.

### 2. `Interop/`
- **`NativeMethods.cs`**: Implements P/Invoke bindings for Win32 API functions:
  - Window Styles: `WS_EX_NOACTIVATE`, `WS_EX_TOOLWINDOW`, `WS_EX_TOPMOST`, `WS_EX_LAYERED`, `WS_EX_TRANSPARENT`.
  - Hooking: `SetWindowsHookEx`, `CallNextHookEx`, `UnhookWindowsHookEx` with hook types `WH_MOUSE_LL` (14) and `WH_KEYBOARD_LL` (13).
  - Cursor & Coordinates: `GetCursorPos`, `ClientToScreen`, DPI-awareness queries (`GetDpiForWindow`, `GetDeviceCaps`).
  - Shell Integration: `ShellExecuteEx` for launching default applications, file explorers, and terminals.
- **`DragGestureMonitor.cs`**: Tracks global file dragging gestures across the desktop and other applications:
  - Detects mouse button state and drag threshold movements.
  - Reads modifier keys asynchronously (`VK_MENU` for Alt, `VK_SHIFT` for Shift, `VK_CONTROL` for Ctrl, `VK_LWIN`/`VK_RWIN` for Windows key).
  - Translates physical screen pixels to Device Independent Pixels (DIP) based on per-monitor DPI scaling.
  - Summons the `RadialWheelWindow` directly under the cursor without stealing window focus from Explorer or third-party apps.
  - Reads Explorer selection from the window where each drag starts. The wheel refreshes its file context from the actual drop payload.
  - Opening a file with the executable starts the contextual Tools wheel. A launch containing only `.3mf` projects opens the printer conversion wheel.

### 3. `Services/`
- **`AssetGenerator.cs`**: Generates required runtime assets on demand without proprietary dependencies:
  - Synthesizes `HighlightSound.wav` (44.1 kHz, 16-bit mono PCM, combining a 1046.5 Hz C6 sine wave and a 1567.98 Hz G6 harmonic chime with smooth exponential decay over 55 milliseconds).
  - Generates multi-size Windows icon `AppIcon.ico` (containing 16×16, 32×32, 48×48, and 256×256 frames with the FlowConverter cyan gradient palette).
- **`SoundService.cs`**: Low-latency, non-blocking acoustic player wrapping `System.Media.SoundPlayer` to provide snappy audio feedback as the cursor enters petals.
- **`TrayIconService.cs`**: Integrates with the Windows Taskbar Notification Area using `System.Windows.Forms.NotifyIcon`:
  - Quick action menu to summon wheels (`Conversions`, `File Tools`, `Quick Actions`).
  - Shortcut to launch the 3MF Studio Inspector, create a new Floating Shelf, open the Welcome Guide, or launch Settings.
  - Dispatches native Windows balloon notifications for completed operations and clipboard events.

### 4. `Engines/`
- **`UniversalConversionEngine.cs`**: Handles all 46 conversion formats:
  - Native Windows Imaging Component (WIC) and GDI+ for high-performance image encoding/decoding.
  - Integrated `flow_office_converter.py` for headless Word, Excel, and PowerPoint conversions.
  - Support for `ffmpeg.exe` and `cwebp.exe` for media and modern image formats.
  - Set up FFmpeg in **Settings → General → Media Tools (FFmpeg)**, through the welcome link, or when a media operation requests it. Choose **Set up now** to download the Windows Essentials build over HTTPS and verify its SHA-256, or select an existing `ffmpeg.exe`. The download installs for the current user under `%LOCALAPPDATA%\FlowConverter\Tools`, and the pending operation continues without restarting.
  - Built-in `System.IO.Compression` pipelines for ZIP/TAR archive operations.
- **`ToolExecutionEngine.cs`**: Executes file operations for all 29 tools (PDF splitting/merging, volume normalization, metadata stripping, video trimming, image filters, and batch processing).
- **`ThreeMFConverterEngine.cs`**: Complete 3D printing profile transformation engine (detailed below).

### 5. `Views/`
- **`RadialWheelWindow.xaml`**:
  - `360×360` transparent, borderless, topmost layered window.
  - Outer ring rendering up to 12 contextual petals with smooth cyan/orange highlight gradients.
  - Central `102×102` control hub displaying the active mode, action title, and description.
  - Non-activating window behavior (`WS_EX_NOACTIVATE`) ensuring drag operations in Windows Explorer or third-party software are never interrupted.
- **`FloatingShelfWindow.xaml`**:
  - Translucent obsidian glass panel for holding files.
  - Compact (`96×112`) and expanded (`280×320`) layout modes.
  - Full drag-and-drop support: drag files in from Explorer, drag files out to other applications, or trigger batch conversion wheels directly from shelf items.
- **`ToolWorkspaceWindow.xaml`**:
  - Interactive multi-tool workspace providing dedicated visual editors:
    - **Visual Image/Video Cropper** with aspect-ratio presets (1:1, 16:9, 4:3, 9:16).
    - **Audio Waveform Trimmer** with a waveform decoded from the first file, draggable start/end handles and selection, 0.1-second adjustments, range playback, reset, and optional silence trimming at both ends. Batch exports apply the selected times to each file and detect its silent ends separately.
    - **Image & Video Redaction Canvas** for drawing blur, black, or pixelate boxes.
    - **QR Code Scanner & Generator** with custom colors, sizing, and error correction levels.
    - **3MF Project Inspector** displaying bed dimensions, filament matrix, slicer origin, and target printer selection.
- **`OperationProgressWindow.xaml`**:
  - Non-modal status dialog displaying overall progress, per-file status messages, and completion logs.
- **`WelcomeWindow.xaml`**:
  - Onboarding dialog introducing modifier gestures (`Alt`, `Shift`, `Ctrl`) and core capabilities.

---

## 🖨️ .3MF Slicer Profile Discovery Paths on Windows

`ThreeMFConverterEngine` inspects local slicer installations to read official system and user-defined print profiles. On Windows, profile candidate directories are resolved in the following priority order:

1. **Bundled Application Fallback Profiles:**
   ```text
   <AppBaseDirectory>\Resources\profiles\
   ```
2. **AnycubicSlicerNext Official Installation Profiles:**
   ```text
   C:\Program Files\AnycubicSlicerNext\resources\profiles\
   ```
   *(e.g., `Anycubic.json`, `Anycubic/machine/`, `Anycubic/process/`, `Anycubic/filament/`)*
3. **AnycubicSlicerNext User Profiles:**
   ```text
   %APPDATA%\AnycubicSlicerNext\system\
   ```
4. **OrcaSlicer Official Installation Profiles:**
   ```text
   C:\Program Files\OrcaSlicer\resources\profiles\
   ```
   *(e.g., `BBL.json`, `Creality.json`, `Elegoo.json`, `Prusa.json`, `Voron.json`)*
5. **OrcaSlicer User Profiles:**
   ```text
   %APPDATA%\OrcaSlicer\system\
   ```
6. **Bambu Studio Official Installation Profiles:**
   ```text
   C:\Program Files\Bambu Studio\resources\profiles\
   ```

### Profile Inheritance Engine
The engine walks recursive `"inherits"` chains:
- Machine configs (`machine_list` / `printer_settings_id`)
- Process configs (`process_list` / `print_settings_id`)
- Filament configs (`filament_list` / `filament_settings_id`)

Base parameters are merged with overrides to establish the full slicer profile schema before applying project-specific overrides.

### Project Intent Preservation & Schema Sanitization
When converting a `.3mf` file from one printer to another:
- **Overrides Preserved:** All user overrides in `Metadata/project_settings.config` (such as `different_settings_to_system`, layer height, infill density/pattern, wall loops, support parameters, prime tower, and brim) are preserved.
- **Multi-Color Slots:** Maps `filament_colour`, `filament_type`, and purge volume matrices across target extruder configurations.
- **Cross-Slicer Sanitization:**
  - Normalizes boolean representations between slicers (`"true"`/`"false"` vs `"1"`/`"0"`).
  - Normalizes scalar vs array types (e.g. `enable_overhang_speed`, `ensure_vertical_shell_thickness`, `nozzle_type`).
  - Cleans `Metadata/slice_info.config` and `Metadata/model_settings.config`.
- **Bed Auto-Recentering:** Parses `3D/3dmodel.model` XML mesh data and automatically recalculates object translation matrices so that printed models are perfectly centered on the destination printer's bed (`BedWidthMM`, `BedDepthMM`).

---

## 🚀 Build, Publish & CLI Instructions

### Prerequisites
- **Operating System:** Windows 10 (version 1809 or higher) or Windows 11 (64-bit)
- **.NET SDK:** [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- **PowerShell:** PowerShell 5.1+ (Windows PowerShell) or PowerShell 7+ (Core)

### Automated Build Script
Run the automated build script from the repository root:

```powershell
cd windows
.\build_windows.ps1
```

The script performs the following steps:
1. Validates that `dotnet` is present on `PATH` or in `%LOCALAPPDATA%\Programs\dotnet\`.
2. Compiles and publishes `src/FlowConverter.Windows/FlowConverter.Windows.csproj` in `Release` configuration to `build\FlowConverter\`.
3. Verifies and copies audio chimes (`HighlightSound.wav`) and helper scripts (`flow_office_converter.py`).
4. Automatically checks for installed Anycubic/Orca profiles in `Program Files` and bundles them into `build\FlowConverter\Resources\profiles\`.

### Manual Build & Publish
You can also build directly using the .NET CLI:

```powershell
# Restore dependencies and build in Debug
dotnet build windows\src\FlowConverter.Windows\FlowConverter.Windows.csproj -c Debug

# Publish Release executable
dotnet publish windows\src\FlowConverter.Windows\FlowConverter.Windows.csproj -c Release -o windows\build\FlowConverter
```

### Headless CLI Commands
FlowConverter supports headless automation for command-line workflows and batch scripts:

```powershell
# 1. Inspect a 3MF project metadata and configuration
.\windows\build\FlowConverter\FlowConverter.exe --inspect-3mf "C:\path\to\project.3mf"

# Output format:
# File: project.3mf
# OriginalPrinter: Bambu Lab X1 Carbon 0.4 nozzle
# Bed: 256x256x256
# Filaments: 4

# 2. Convert a 3MF project to a target 3D printer
.\windows\build\FlowConverter\FlowConverter.exe --convert-3mf "C:\path\to\project.3mf" "Anycubic Kobra 3"

# Output format:
# Converted3MF: C:\path\to\project_Anycubic_Kobra_3.3mf
```

### Windows Keyboard & Gesture Summary

| Shortcut Key | Action |
| :--- | :--- |
| **`Alt` + Drag** | Summons the **Conversion Wheel** centered at cursor position. |
| **`Shift` + Drag** / **`Win` + Drag** | Summons the **File Tools Wheel** centered at cursor position. |
| **`Ctrl` + Drag** | Summons the **Quick Actions Wheel** (`Float`, `Share`, `Copy`, `Move`, `Copy Path`, `Terminal`). |
| **Center Hub Click** | Switches between the 3 wheel modes (`Conversions` ➔ `File Tools` ➔ `Quick Actions`). |
| **`Esc` / Release Outside** | Closes the radial overlay without executing. |
| **Tray Icon Click** | Left-click tray icon to summon the default wheel; right-click for the context menu. |
