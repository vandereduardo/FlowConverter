# FlowConverter for Windows (Architecture & Port Roadmap)

This directory contains the specification and structure for the **Windows 10/11** native port of **FlowConverter**.

## Target Stack
- **Runtime:** .NET 8 (`net8.0-windows10.0.19041.0`)
- **UI Framework:** WPF / WinUI 3 with transparent layered overlay windows (`WS_EX_LAYERED | WS_EX_TRANSPARENT` when click-through, `Acrylic` / `Mica` backdrop)
- **Global Drag & Modifier Detection:**
  - Low-level mouse & keyboard hooks (`SetWindowsHookEx` with `WH_MOUSE_LL` and `WH_KEYBOARD_LL`) + OLE `IDropTarget` registration on the Radial Wheel overlay window when `Alt` (`VK_MENU`) is held during an Explorer drag operation.
- **Engines Shared with macOS:**
  - **3MF Printer Converter:** Uses the same `Metadata/project_settings.config`, `different_settings_to_system`, and `Metadata/model_settings.config` sanitizer logic, reading installed slicer profiles from `%APPDATA%\AnycubicSlicerNext\`, `%ProgramFiles%\AnycubicSlicerNext\resources\profiles`, and `%ProgramFiles%\OrcaSlicer\resources\profiles`.
  - **Media & Image Pipeline:** `ffmpeg.exe`, `cwebp.exe`, and Windows Imaging Component (WIC).
  - **Office & Tabular Pipeline:** Shared `flow_office_converter.py` or native OpenXML SDK.
