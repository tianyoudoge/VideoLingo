#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/VideoLingo.app"
EXE="$ROOT/app/.build/debug/VideoLingoApp"

swift build --package-path "$ROOT/app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/whisper" "$APP/Contents/Resources/licenses"
cp "$EXE" "$APP/Contents/MacOS/VideoLingoApp"
cp "$ROOT/bin/videolingo-backend" "$APP/Contents/MacOS/videolingo-backend"
cp "$ROOT/app/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/app/Assets/UI/app-icon.png" "$APP/Contents/Resources/app-icon.png"

cp "$ROOT/vendor/whisper.cpp/build/bin/whisper-cli" "$APP/Contents/Resources/whisper/whisper-cli"
cp "$ROOT/vendor/whisper.cpp/build/bin/"lib*.dylib "$APP/Contents/Resources/whisper/"
cp "$ROOT/vendor/whisper.cpp/LICENSE" "$APP/Contents/Resources/licenses/whisper.cpp-LICENSE"

chmod +x "$APP/Contents/MacOS/videolingo-backend" "$APP/Contents/Resources/whisper/whisper-cli"
for binary in "$APP/Contents/Resources/whisper/whisper-cli" "$APP/Contents/Resources/whisper/"*.dylib; do
  install_name_tool -add_rpath "@loader_path" "$binary" 2>/dev/null || true
  install_name_tool -delete_rpath "$ROOT/vendor/whisper.cpp/build/bin" "$binary" 2>/dev/null || true
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>VideoLingoApp</string>
  <key>CFBundleIdentifier</key>
  <string>app.videolingo.desktop</string>
  <key>CFBundleName</key>
  <string>VideoLingo</string>
  <key>CFBundleDisplayName</key>
  <string>VideoLingo</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built: $APP"
