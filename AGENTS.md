# AGENTS.md — FlowConverter Project Guidelines & Rules

## 1. Project Overview & Clean-Room Philosophy
**FlowConverter** (`Flow Converter`) is a fast, 100% clean-room open-source (MIT License) radial file converter, floating drop shelf, media studio, and 3D printer `.3MF` profile converter for **macOS** and **Windows**.

- **Zero Proprietary Assets:** All source code, icons (`AppIcon.icns` / `AppIcon.ico`), sound effects (`HighlightSound.wav`), and helper scripts are generated or written from scratch.
- **Cross-Platform Feature Parity:** Both `macos/` and `windows/` implementations share the same core domain models, visual design language, 46 conversion formats, 29 file tools, and 84-model `.3MF` 3D printer profile converter engine.

---

## 2. Repository Structure

```text
FlowConverter/
├── AGENTS.md                   # AI Agent & Contributor rules, architecture & workflow standards
├── README.md                   # Public repository overview, features & build instructions
├── LICENSE                     # MIT License
├── docs/
│   └── ARCHITECTURE.md         # Cross-platform technical architecture documentation
├── macos/                      # Native macOS App (Swift / AppKit / SwiftUI / CoreGraphics)
│   ├── Sources/FlowConverter/  # 8 modular Swift source files
│   ├── Resources/              # Generated AppIcon.icns, HighlightSound.wav, Info.plist & scripts
│   ├── Scripts/                # Programmatic icon & harmonic WAV generator
│   └── build_app.sh            # Zero-dependency macOS .app bundle builder
└── windows/                    # Native Windows App (.NET 8 / WPF / Win32 Interop)
    ├── README.md               # Windows architecture, requirements & build instructions
    ├── build_windows.ps1       # Zero-dependency Windows build & bundle script
    ├── FlowConverter.sln       # Visual Studio / .NET 8 Solution
    └── src/FlowConverter.Windows/
        ├── FlowConverter.Windows.csproj
        ├── App.xaml / App.xaml.cs
        ├── Models/             # ConversionFormat, FileTool, Printer3DModel (84 models), Settings
        ├── Interop/            # Win32 Hooks (WH_MOUSE_LL, WH_KEYBOARD_LL), Layered Window, Shell
        ├── Views/              # RadialWheelWindow, FloatingShelfWindow, ToolWorkspaceWindow, SettingsWindow, WelcomeWindow, ProgressWindow
        ├── Engines/            # ConversionEngine, ToolExecutionEngine, ThreeMFConverterEngine
        └── Services/           # SoundPlayer, TrayIconService, AssetGenerator, StartupManager
```

---

## 3. Git, Branching & Pull Request Workflow

Because **FlowConverter** is a public open-source repository, all development must strictly follow these version-control rules:

1. **No Direct Commits to `main`:**
   - Never commit or push directly to `main`.
   - Always create a descriptive branch before making changes:
     - `feat/<scope>-<description>` (e.g., `feat/windows-native-port`, `feat/3mf-profile-sync`)
     - `fix/<scope>-<description>` (e.g., `fix/windows-wheel-dpi`)
     - `docs/<description>` (e.g., `docs/windows-architecture`)
     - `chore/<description>`
2. **Conventional Commits:**
   - Format: `<type>(<scope>): <concise summary in imperative mood>`
   - Examples:
     - `feat(windows): implement radial wheel overlay and Win32 drag monitor`
     - `feat(windows): port ThreeMFConverterEngine with Anycubic and OrcaSlicer profile chains`
     - `docs(readme): document Windows build and runtime instructions`
3. **Pull Requests (PRs):**
   - Every branch must be pushed to `origin` and merged via a GitHub Pull Request.
   - PR descriptions must include:
     - **Summary** of changes and architectural decisions.
     - **Modules Affected** (`windows/`, `macos/`, `docs/`).
     - **Verification / Test Plan** confirming build and runtime validation.
4. **Documentation Synchronization:**
   - Whenever features, CLI scripts, UI workflows, or architecture change, update:
     - `README.md` (root)
     - `windows/README.md` (when working on Windows)
     - `docs/ARCHITECTURE.md`
   - Documentation updates must be included in the same PR before merging.

---

## 4. Visual Identity & Design System

Both macOS and Windows apps share a cohesive "Cockpit Radial Wheel" aesthetic:
- **Primary Accent Color:** Electric Cyan `#00E5FF` (`RGB(0, 229, 255)`)
- **Active Petal Highlight Gradient:** Vibrant Orange `#FF6B0D` (`RGB(255, 107, 13)`) to `#E64200` (`RGB(230, 66, 0)`)
- **Surface Themes (`ConversionFanTheme`):**
  - `Glass`: Translucent dark obsidian (`#38383C` → `#1A1A1E` at ~80% opacity)
  - `Metallic`: High-contrast dark metallic (`#47474D` → `#242429` at ~93% opacity)
- **Audio Feedback:** Clean-room synthesized `HighlightSound.wav` (`44.1 kHz`, 16-bit mono, `55ms` harmonic chime combining `1046.5 Hz` C6 + `1567.98 Hz` G6 sine waves with exponential decay).

---

## 5. Core Technical Requirements (Windows Port Parity)

1. **Target Framework & Tooling:**
   - `.NET 8.0` (`net8.0-windows`) using **WPF** (`UseWPF=true`) and **Windows Forms Interop** (`UseWindowsForms=true` for native system tray `NotifyIcon` and folder dialogs).
   - Executable paths on the local dev machine:
     - Git: `%LOCALAPPDATA%\Programs\Git\cmd\git.exe`
     - .NET SDK: `%LOCALAPPDATA%\Programs\dotnet\dotnet.exe`
2. **Radial Wheel Overlay (`RadialWheelWindow`):**
   - `360×360` borderless, transparent, topmost, non-activating (`WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST`) window centered at cursor coordinates.
   - 3 Modes:
     - **Convert (`Alt` + Drag):** Compatible output formats (up to 12 petals) or `.3MF` target 3D printers when dragging `.3mf` files.
     - **Tools (`Win` / `Shift` + Drag):** Context-aware file tools (`FileTool.CompatibleTools`).
     - **Actions (`Ctrl` + Drag):** `Float`, `Share / Send To`, `Copy`, `Move`, `Copy Path`, `Open Terminal`.
   - Center Hub (`102×102` disk with `#00E5FF` border): Displays active mode and hovered petal description; clicking cycles modes (`Convert` → `Tools` → `Actions`).
3. **3D Printer `.3MF` Profile Converter (`ThreeMFConverterEngine`):**
   - Full catalog of **84 preset 3D printers across 12 brands** (`Anycubic`, `Bambu Lab`, `Creality`, `Flashforge`, `Elegoo`, `Prusa`, `Qidi Tech`, `Sovol`, `Artillery`, `Flsun`, `Voron`, `Two Trees`) + Custom printers.
   - Reads official slicer profiles from:
     - Bundled `Resources/profiles`
     - `C:\Program Files\AnycubicSlicerNext\resources\profiles` and `%APPDATA%\AnycubicSlicerNext`
     - `C:\Program Files\OrcaSlicer\resources\profiles` and `%APPDATA%\OrcaSlicer`
     - `C:\Program Files\Bambu Studio\resources\profiles`
   - Walks `"inherits"` chains across `machine_list`, `process_list`, and `filament_list`.
   - Preserves `different_settings_to_system`, `inherits_group`, multi-color filament slots (`filament_colour`, `filament_type`, purge volumes), applies `ThreeMFOptimizationPreset`, performs cross-slicer sanitization (`ensure_vertical_shell_thickness`, `enable_overhang_speed`, `nozzle_type`, boolean normalization, scalar de-duplication), sanitizes `slice_info.config` and `model_settings.config`, and auto-recenters build items on the target bed in `3D/3dmodel.model`.
4. **Floating Drop Shelf ("Float"):**
   - Expanded (`280×320`) and Compact (`96×112`) floating modes.
   - Supports dragging files in and out, Icons/List toggle, file previews, Copy All, and context menu actions.
5. **Universal Conversion Engine & Interactive Tool Workspace:**
   - Supports all 46 formats and 29 tools with native Windows imaging/PDF/archive pipelines, `flow_office_converter.py`, and `ffmpeg` / `cwebp` integration.
   - Interactive editors for Visual Crop, Audio Waveform Trimmer, Image/Video Redaction, Image Adjustments, Frame/Background, Annotate, Collage, PDF Organizer/Merge/Split, QR Code Scanner/Generator, and `.3MF` Project Inspector.
