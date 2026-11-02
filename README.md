# FlowConverter (`Flow Converter`)

**FlowConverter** is a fast, open-source radial file converter, floating drop shelf, media studio, and 3D printer `.3MF` profile converter built from the ground up.

Inspired by modern cockpit radial wheels (`//Flow` style), **FlowConverter** summons an interactive radial wheel right under your cursor when dragging files while holding your modifier key (`⌥ Option` on macOS, `Alt` on Windows).

---

## ✨ Key Features

1. **Radial Conversion Wheel (`⌥ Option` + Drag)**
   - Instant contextual petals tailored to the dragged file type (Images, Video, Audio, Documents, Spreadsheets, Presentations, Subtitles, Archives, and `.3MF` 3D Print Projects).
   - Multi-file batch support including one-drop **ZIP** archiving.
2. **Floating Drop Shelf**
   - Hold files temporarily in a floating glass shelf while switching folders or apps, or trigger batch conversions directly from the shelf.
3. **3D Printer `.3MF` Profile Converter**
   - Built-in catalog of **80+ 3D printers across 12 manufacturers** (*Anycubic Kobra X*, *Kobra 4*, *Kobra 3*, *Kobra S1*, *Bambu Lab X1C / P1S / A1 / H2D*, *Creality K1 / K2 Plus / Ender-3*, *Flashforge*, *Elegoo*, *Prusa*, *Qidi*, *Sovol*, *Voron*, and custom printers).
   - Loads official `machine`, `process`, and `filament` profile chains from **AnycubicSlicerNext** and **OrcaSlicer**.
   - Preserves multi-color filament slots (`filament_colour`, `filament_type`, purge volumes) and **all custom project overrides** (`different_settings_to_system`, infill density/pattern, wall speeds, supports, prime tower) while sanitizing cross-slicer schema differences.
4. **Interactive Visual & Audio Tools**
   - **Interactive Audio Waveform Trimmer:** Drag start/end handles on a real-time waveform with live audio preview.
   - **Interactive Video & Image Redaction:** Draw black, blur, or pixelate boxes on a live video/image canvas with timeline scrubbing.
   - **Visual Image & Video Cropper:** Aspect-ratio presets and interactive handles.
   - **Audio Visualizer:** Hardware-accelerated (`VideoToolbox`) spectrum, waveform, and circular bar video generator for MP3/WAV/FLAC audio.
   - **PDF & QR Suite:** Merge/Split/Organize PDFs, extract text/images, scan QR codes, and generate custom styled QR codes.

---

## 📁 Multi-Platform Repository Structure

```text
FlowConverter/
├── macos/                      # Native macOS App (Swift / AppKit / SwiftUI / CoreGraphics)
│   ├── Sources/FlowConverter/  # 100% clean-room Swift source code
│   ├── Resources/              # Generated AppIcon.icns, HighlightSound.wav, Info.plist & Python/JXA helpers
│   ├── Scripts/                # Asset generator (CoreGraphics icon & harmonic WAV synthesis)
│   └── build_app.sh            # Zero-dependency macOS app bundle builder
├── windows/                    # Windows Port Architecture & Specification (.NET 8 / WinUI 3 / WPF)
│   └── README.md
├── shared/                     # Cross-platform printer presets & shared schemas
└── docs/                       # Technical architecture documentation
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

## 📄 License

Released under the [MIT License](LICENSE). Clean-room open-source implementation with zero proprietary code or assets.
