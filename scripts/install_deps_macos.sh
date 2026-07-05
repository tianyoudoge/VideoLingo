#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh"
  exit 1
fi

brew install go ffmpeg cmake git

mkdir -p "$ROOT/vendor" "$ROOT/bin"
if [ ! -d "$ROOT/vendor/whisper.cpp/.git" ]; then
  git clone https://github.com/ggml-org/whisper.cpp "$ROOT/vendor/whisper.cpp"
fi

cmake -S "$ROOT/vendor/whisper.cpp" -B "$ROOT/vendor/whisper.cpp/build" -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT/vendor/whisper.cpp/build" --config Release -j"$(sysctl -n hw.ncpu)"

WHISPER_BIN="$(find "$ROOT/vendor/whisper.cpp/build" -type f -name whisper-cli | head -1)"
if [ -z "$WHISPER_BIN" ]; then
  echo "whisper-cli was not found after build"
  exit 1
fi
ln -sf "$WHISPER_BIN" "$ROOT/bin/whisper-cli"

echo "Installed dependencies. whisper-cli -> $ROOT/bin/whisper-cli"

