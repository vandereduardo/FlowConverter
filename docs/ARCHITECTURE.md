# FlowConverter Clean-Room Architecture

## Overview
**FlowConverter** is a 100% clean-room open-source desktop utility written from scratch. No proprietary source code, binaries, scripts, icons, or audio assets from third-party commercial applications are included.

## Core Modules (`macos/Sources/FlowConverter/`)
1. **`Models.swift`**: Data models for file formats (`ConversionFormat`), tools (`FileTool`), 3D printer catalog (`Printer3DModel` with 80+ models across 12 brands), and user options.
2. **`RadialWheelOverlay.swift`**: CoreGraphics/SwiftUI radial wheel overlay (`NSPanel` + `NSDraggingDestination`) that appears at cursor coordinates when holding the trigger modifier key during file drag.
3. **`FloatingShelfWindow.swift`**: Temporary drag-and-drop holding shelf and quick-action bar.
4. **`ConversionEngine.swift`**: Format conversion router using macOS native frameworks (`ImageIO`, `PDFKit`, `AVFoundation`), `Scripts/flow_office_converter.py`, and open-source `ffmpeg` / `cwebp`.
5. **`ToolExecutionEngine.swift`**: Specialized file tools (Audio Trim, Video Redaction, Audio Visualizer, Collage, PDF Merge/Split, Metadata Stripper, and **`ThreeMFConverterEngine`**).
6. **`ToolWorkspaceWindow.swift`**: Interactive editors for Waveform Audio Trimming, Video/Image Redaction, Visual Cropping, QR Generator, and 3MF Project Inspector.
7. **`SettingsWindow.swift`**: Preferences window for themes, shortcuts, and 3D Printer `.3MF` catalog management.
8. **`AppDelegate.swift`**: Menu bar controller, global drag monitor, and single-instance lifecycle manager.
