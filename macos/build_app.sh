#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
SRC_DIR="$SCRIPT_DIR/Sources/FlowConverter"
RES_DIR="$SCRIPT_DIR/Resources"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/FlowConverter.app"

echo "[1/4] Preparing FlowConverter.app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/Scripts"
mkdir -p "$APP_BUNDLE/Contents/Resources/Tools"

if [[ ! -f "$RES_DIR/AppIcon.icns" || ! -f "$RES_DIR/HighlightSound.wav" ]]; then
    echo "Generating clean-room AppIcon.icns and HighlightSound.wav..."
    xcrun swift -module-cache-path /tmp/rea-swift-module-cache "$SCRIPT_DIR/Scripts/generate_assets.swift" "$RES_DIR"
fi

echo "[2/4] Compiling FlowConverter Swift sources (Universal Binary: arm64 + x86_64)..."
SWIFT_SOURCES=(
  "$SRC_DIR/Models.swift"
  "$SRC_DIR/SettingsWindow.swift"
  "$SRC_DIR/RadialWheelOverlay.swift"
  "$SRC_DIR/FloatingShelfWindow.swift"
  "$SRC_DIR/ConversionEngine.swift"
  "$SRC_DIR/ToolWorkspaceWindow.swift"
  "$SRC_DIR/ToolExecutionEngine.swift"
  "$SRC_DIR/AppDelegate.swift"
)

TARGET_ARCH="${1:-universal}"
if [[ "$TARGET_ARCH" == "x86_64" || "$TARGET_ARCH" == "intel" ]]; then
    xcrun swiftc -module-cache-path /tmp/rea-swift-module-cache -O -target x86_64-apple-macosx13.0 \
      "${SWIFT_SOURCES[@]}" \
      -o "$APP_BUNDLE/Contents/MacOS/FlowConverter"
elif [[ "$TARGET_ARCH" == "arm64" ]]; then
    xcrun swiftc -module-cache-path /tmp/rea-swift-module-cache -O -target arm64-apple-macosx13.0 \
      "${SWIFT_SOURCES[@]}" \
      -o "$APP_BUNDLE/Contents/MacOS/FlowConverter"
else
    xcrun swiftc -module-cache-path /tmp/rea-swift-module-cache -O -target arm64-apple-macosx13.0 \
      "${SWIFT_SOURCES[@]}" \
      -o "$BUILD_DIR/FlowConverter-arm64"
    xcrun swiftc -module-cache-path /tmp/rea-swift-module-cache -O -target x86_64-apple-macosx13.0 \
      "${SWIFT_SOURCES[@]}" \
      -o "$BUILD_DIR/FlowConverter-x86_64"
    lipo -create "$BUILD_DIR/FlowConverter-arm64" "$BUILD_DIR/FlowConverter-x86_64" \
      -output "$APP_BUNDLE/Contents/MacOS/FlowConverter"
    rm -f "$BUILD_DIR/FlowConverter-arm64" "$BUILD_DIR/FlowConverter-x86_64"
fi

echo "[3/4] Copying clean-room Info.plist, icons, sounds, scripts, and open-source CLI tools..."
cp "$RES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$RES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$RES_DIR/HighlightSound.wav" "$APP_BUNDLE/Contents/Resources/HighlightSound.wav"
cp "$RES_DIR/Scripts/flow_office_converter.py" "$APP_BUNDLE/Contents/Resources/Scripts/flow_office_converter.py"
cp "$RES_DIR/Scripts/flow_pages_export.js" "$APP_BUNDLE/Contents/Resources/Scripts/flow_pages_export.js"
chmod +x "$APP_BUNDLE/Contents/Resources/Scripts/flow_office_converter.py"

# Bundle open-source ffmpeg & cwebp if available locally or via Homebrew (matching target architecture)
for tool in ffmpeg cwebp; do
    CANDIDATE=""
    if [[ -x "$RES_DIR/Tools/$tool" ]]; then
        CANDIDATE="$RES_DIR/Tools/$tool"
    elif [[ "$TARGET_ARCH" == "x86_64" || "$TARGET_ARCH" == "intel" ]] && [[ -x "/usr/local/bin/$tool" ]]; then
        CANDIDATE="/usr/local/bin/$tool"
    elif [[ -x "/opt/homebrew/bin/$tool" ]]; then
        CANDIDATE="/opt/homebrew/bin/$tool"
    fi
    if [[ -n "$CANDIDATE" ]]; then
        if [[ "$TARGET_ARCH" == "x86_64" || "$TARGET_ARCH" == "intel" ]]; then
            if file "$CANDIDATE" | grep -q "x86_64"; then
                cp "$CANDIDATE" "$APP_BUNDLE/Contents/Resources/Tools/$tool"
            fi
        else
            cp "$CANDIDATE" "$APP_BUNDLE/Contents/Resources/Tools/$tool"
        fi
    fi
done

# Bundle official 3D slicer profiles (AnycubicSlicerNext & OrcaSlicer) if installed on build machine
/usr/bin/python3 -c '
import json, os, shutil

dst_base = os.path.join("'"$APP_BUNDLE"'", "Contents/Resources/profiles")
sources = [
    ("/Applications/AnycubicSlicerNext.app/Contents/Resources/profiles", "Anycubic"),
    ("/Applications/OrcaSlicer.app/Contents/Resources/profiles", "Flashforge"),
    ("/Applications/OrcaSlicer.app/Contents/Resources/profiles", "Snapmaker"),
]
for src_base, vendor in sources:
    idx_path = os.path.join(src_base, f"{vendor}.json")
    if os.path.exists(idx_path):
        os.makedirs(dst_base, exist_ok=True)
        shutil.copyfile(idx_path, os.path.join(dst_base, f"{vendor}.json"))
        with open(idx_path) as f:
            idx = json.load(f)
        for k in ("machine_model_list", "machine_list", "process_list", "filament_list"):
            for item in idx.get(k, []):
                sp = item.get("sub_path")
                if sp:
                    s = os.path.join(src_base, vendor, sp)
                    d = os.path.join(dst_base, vendor, sp)
                    if os.path.exists(s):
                        os.makedirs(os.path.dirname(d), exist_ok=True)
                        try:
                            shutil.copyfile(s, d)
                        except Exception:
                            pass
'

echo "[4/4] Signing $APP_BUNDLE..."
chmod -R u+w "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"
find "$APP_BUNDLE/Contents/Resources/Tools" -type f -perm +111 -exec codesign --force --sign - {} \; 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
