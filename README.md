# FlowConverter (`Flow Converter`)

**FlowConverter** is a fast, open-source radial file converter, floating drop shelf, media studio, and 3D printer `.3MF` profile converter built from the ground up for **macOS** and **Windows**.

Inspired by modern cockpit radial wheels (`//Flow` style), **FlowConverter** summons an interactive radial wheel right under your cursor when dragging files while holding your modifier key (`⌥ Option` on macOS, `Alt` on Windows).

On Windows, the wheel uses narrow gaps between petals and displays native Windows icons above the Tools and Actions labels.
Windows Settings uses dark input fields, dropdowns, and checkboxes.

On Windows, **Settings → General → Media Tools (FFmpeg)** can install FFmpeg on demand or use an existing executable. Audio and video tools offer setup when needed and continue in the same session.

Opening a file directly with FlowConverter on Windows shows tools for that file. Opening only `.3mf` projects shows the printer conversion wheel.

FlowConverter for Windows offers **English** and **Português (Brasil)** on first launch. Change the choice under **Settings → General → App Language** and reopen the app to apply it. [Track macOS localization](https://github.com/vandereduardo/FlowConverter/issues/2).

---

## ✨ Key Features

1. **Radial Conversion Wheel (`⌥ Option` on macOS / `Alt` on Windows + Drag)**
   - Instant contextual petals tailored to the dragged file type (Images, Video, Audio, Documents, Spreadsheets, Presentations, Subtitles, Archives, and `.3MF` 3D Print Projects).
   - Multi-file batch support including one-drop **ZIP** archiving.
   - Interactive 3-mode wheel overlay:
     - **Conversions Mode:** Format conversion petals (up to 12 petals) or target 3D printer petals for `.3mf` files.
     - **File Tools Mode (`Shift` / `Win` + Drag):** 29 context-aware file utilities (Crop, Trim, Redact, Compress, Normalize, Organize).
     - **Quick Actions Mode (`Ctrl` + Drag):** Instant workflow actions (Float, Copy, Move, Copy Path, Open Terminal).
   - Center hub displays active action descriptions, status indicators, and cycles modes upon clicking.

2. **Floating Drop Shelf ("Float")**
   - Hold files temporarily in a floating glass or metallic shelf while switching folders or apps.
   - Supports dragging files in and out, quick previews, copying paths/files, and triggering batch conversions directly from the shelf.
   - Compact (`96×112`) and expanded (`280×320`) display modes.

3. **3D Printer `.3MF` Profile Converter**
   - Built-in catalog of **84 3D printers across 12 manufacturers** (*Anycubic Kobra X*, *Kobra 4*, *Kobra 3*, *Kobra S1*, *Bambu Lab X1C / P1S / A1 / H2D*, *Creality K1 / K2 Plus / Ender-3*, *Flashforge*, *Elegoo*, *Prusa*, *Qidi Tech*, *Sovol*, *Artillery*, *Flsun*, *Voron*, *Two Trees*, and custom printers).
   - Reads official slicer profile inheritance chains (`machine_list`, `process_list`, `filament_list`) from **AnycubicSlicerNext**, **OrcaSlicer**, and **Bambu Studio**.
   - Preserves multi-color filament slots (`filament_colour`, `filament_type`, purge volumes) and **all custom project overrides** (`different_settings_to_system`, infill density/pattern, wall speeds, supports, prime tower) while sanitizing cross-slicer schema differences.
   - Automatic bed recentering: parses `3D/3dmodel.model` and re-centers model objects on the destination printer's print bed.

4. **Interactive Visual & Audio Studio**
   - **Interactive Audio Waveform Trimmer:** Drag start/end handles on a real-time waveform with live audio preview.
     On Windows, play the selected range, reset to the full audio, or trim silent ends with an adjustable threshold.
   - **Interactive Video & Image Redaction:** Draw black, blur, or pixelate boxes on a live video/image canvas with timeline scrubbing.
     On Windows, the photo preview preserves the image proportions and limits the selection to the image edges.
   - **Visual Image & Video Cropper:** Aspect-ratio presets and interactive crop handles.
     On Windows, the image preview preserves the source proportions, and the selected aspect ratio applies while dragging and saving.
   - **Image Adjustments on Windows:** Preview exposure, brightness, contrast, and saturation while editing.
   - **Audio Visualizer:** Hardware-accelerated spectrum, waveform, and circular bar video generator for MP3/WAV/FLAC audio.
   - **PDF & QR Suite:** Merge, split, and organize PDF pages; extract text and images; scan and generate styled QR codes.

---

## 📁 Multi-Platform Repository Structure

```text
FlowConverter/
├── AGENTS.md                   # AI Agent & Contributor rules, architecture & workflow standards
├── README.md                   # Public repository overview, features & build instructions
├── LICENSE                     # MIT License
├── docs/
│   └── ARCHITECTURE.md         # Cross-platform technical architecture documentation
├── macos/                      # Native macOS App (Swift / AppKit / SwiftUI / CoreGraphics)
│   ├── Sources/FlowConverter/  # 8 modular Swift source files
│   │   ├── AppDelegate.swift
│   │   ├── ConversionEngine.swift
│   │   ├── FloatingShelfWindow.swift
│   │   ├── Models.swift
│   │   ├── RadialWheelOverlay.swift
│   │   ├── SettingsWindow.swift
│   │   ├── ToolExecutionEngine.swift
│   │   └── ToolWorkspaceWindow.swift
│   ├── Resources/              # Generated AppIcon.icns, HighlightSound.wav, Info.plist & scripts
│   ├── Scripts/                # Asset generator (CoreGraphics icon & harmonic WAV synthesis)
│   └── build_app.sh            # Zero-dependency macOS app bundle builder
└── windows/                    # Native Windows App (.NET 8 / WPF / Win32 Interop)
    ├── README.md               # Windows architecture, feature matrix & build guide
    ├── build_windows.ps1       # Zero-dependency Windows build & bundle script
    ├── FlowConverter.sln       # Visual Studio / .NET 8 solution
    └── src/FlowConverter.Windows/
        ├── FlowConverter.Windows.csproj
        ├── App.xaml / App.xaml.cs
        ├── Models/             # ConversionModels.cs, FileToolModels.cs, Printer3DModels.cs, SettingsModel.cs
        ├── Interop/            # NativeMethods.cs, DragGestureMonitor.cs (WH_MOUSE_LL, WH_KEYBOARD_LL)
        ├── Services/           # SoundService.cs, AssetGenerator.cs, TrayIconService.cs
        ├── Engines/            # UniversalConversionEngine.cs, ToolExecutionEngine.cs, ThreeMFConverterEngine.cs
        └── Views/              # RadialWheelWindow, FloatingShelfWindow, ToolWorkspaceWindow, OperationProgressWindow, WelcomeWindow
```

---

## 🚀 Building on macOS

Requirements: macOS 13.0+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
cd macos
chmod +x build_app.sh
./build_app.sh
open -n build/FlowConverter.app
```

---

## 🚀 Building & Running on Windows

### Requirements
- **Operating System:** Windows 10 (1809+) or Windows 11 (64-bit)
- **SDK:** [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (`dotnet.exe`)
- **PowerShell:** PowerShell 5.1+ or PowerShell 7+

### Build & Package
Run the zero-dependency PowerShell build script from the repository root:

```powershell
cd windows
.\build_windows.ps1
```

The script publishes the Windows bundle to `windows\build\FlowConverter\`. The executable embeds the macOS artwork as a multi-resolution Windows icon. Windows screens share a warm neutral palette, and the radial wheel uses light petals with orange for the active selection.

To run the application:
```powershell
.\build\FlowConverter\FlowConverter.exe
```

### Headless CLI Usage
FlowConverter for Windows includes CLI commands for automated batch processing, scripting, and CI/CD pipelines:

```powershell
# Inspect a 3D print project (.3MF)
.\build\FlowConverter\FlowConverter.exe --inspect-3mf "C:\Models\benchy.3mf"

# Convert a .3MF project to a target 3D printer profile
.\build\FlowConverter\FlowConverter.exe --convert-3mf "C:\Models\benchy.3mf" "Kobra 3"
```

### Windows Keyboard & Drag Gestures

| Shortcut | Gesture | Triggered Action |
| :--- | :--- | :--- |
| **`Alt` + Drag** | Drag file(s) while holding `Alt` | **Radial Conversion Wheel** — compatible format petals or target 3D printer petals for `.3mf` files |
| **`Shift` + Drag** (or `Win` + Drag) | Drag file(s) while holding `Shift` | **Contextual File Tools Wheel** — 29 file tools (Crop, Trim, Redact, Compress, Normalize, Organize) |
| **`Ctrl` + Drag** | Drag file(s) while holding `Ctrl` | **Quick Actions Wheel** — `Float`, `Copy`, `Move`, `Copy Path`, `Open Terminal` |
| **Center Hub Click** | Click center disk | Cycles wheel modes: `Conversions` ➔ `File Tools` ➔ `Quick Actions` |
| **Esc / Release Outside** | Release drag outside petals or press `Esc` | Dismisses the overlay window without executing actions |

---

## 📄 License

Released under the [MIT License](LICENSE). Clean-room open-source implementation with zero proprietary code or assets.
