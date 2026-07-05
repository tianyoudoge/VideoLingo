#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

mkdir -p "$DIST"

if [ ! -x "$ROOT/bin/whisper-cli" ]; then
  "$ROOT/scripts/install_deps_macos.sh"
fi

"$ROOT/scripts/build_backend.sh"
swift "$ROOT/scripts/make_simple_icon.swift"
iconutil -c icns "$ROOT/app/Assets/AppIcon.iconset" -o "$ROOT/app/Assets/AppIcon.icns"
"$ROOT/scripts/build_app_bundle.sh"

rm -f "$DIST/VideoLingo-macOS-arm64.zip"
ditto -c -k --keepParent "$ROOT/VideoLingo.app" "$DIST/VideoLingo-macOS-arm64.zip"

echo "Release artifact: $DIST/VideoLingo-macOS-arm64.zip"
