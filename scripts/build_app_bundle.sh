#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/CaptionFlow.app"
EXE="$ROOT/app/.build/debug/CaptionFlowApp"

swift build --package-path "$ROOT/app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources/whisper" "$APP/Contents/Resources/licenses"
cp "$EXE" "$APP/Contents/MacOS/CaptionFlowApp"
cp "$ROOT/app/.build/debug/libAMSMB2.dylib" "$APP/Contents/Frameworks/libAMSMB2.dylib"
cp "$ROOT/bin/captionflow-backend" "$APP/Contents/MacOS/captionflow-backend"
cp "$ROOT/app/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/app/Assets/UI/app-icon.png" "$APP/Contents/Resources/app-icon.png"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/licenses/CaptionFlow-LICENSE"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/licenses/THIRD_PARTY_NOTICES.md"
cp "$ROOT/app/.build/checkouts/AMSMB2/LICENSE" "$APP/Contents/Resources/licenses/AMSMB2-LICENSE"
cp "$ROOT/app/.build/checkouts/AMSMB2/Dependencies/libsmb2/COPYING" "$APP/Contents/Resources/licenses/libsmb2-COPYING"
git -C "$ROOT/app/.build/checkouts/AMSMB2" archive --format=tar.gz --output="$APP/Contents/Resources/licenses/AMSMB2-4.0.3-source.tar.gz" HEAD
git -C "$ROOT/app/.build/checkouts/AMSMB2/Dependencies/libsmb2" archive --format=tar.gz --output="$APP/Contents/Resources/licenses/libsmb2-source.tar.gz" HEAD

cp "$ROOT/vendor/whisper.cpp/build/bin/whisper-cli" "$APP/Contents/Resources/whisper/whisper-cli"
cp "$ROOT/vendor/whisper.cpp/build/bin/"lib*.dylib "$APP/Contents/Resources/whisper/"
cp "$ROOT/vendor/whisper.cpp/LICENSE" "$APP/Contents/Resources/licenses/whisper.cpp-LICENSE"

chmod +x "$APP/Contents/MacOS/captionflow-backend" "$APP/Contents/Resources/whisper/whisper-cli"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/CaptionFlowApp" 2>/dev/null || true
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
  <string>CaptionFlowApp</string>
  <key>CFBundleIdentifier</key>
  <string>app.captionflow.desktop</string>
  <key>CFBundleName</key>
  <string>CaptionFlow</string>
  <key>CFBundleDisplayName</key>
  <string>CaptionFlow</string>
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
  <key>NSLocalNetworkUsageDescription</key>
  <string>CaptionFlow uses the local network to discover and browse SMB video shares.</string>
  <key>NSBonjourServices</key>
  <array>
    <string>_smb._tcp</string>
  </array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"

echo "Built: $APP"
