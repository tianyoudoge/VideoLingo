#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/models"

MODEL="$ROOT/models/ggml-medium.bin"
MIN_BYTES=1000000000
if [ -f "$MODEL" ]; then
  SIZE="$(stat -f%z "$MODEL")"
  if [ "$SIZE" -ge "$MIN_BYTES" ] && [ ! -f "$MODEL.aria2" ]; then
    echo "Model already exists: $MODEL"
    exit 0
  fi
  echo "Partial model found, resuming download: $MODEL ($SIZE bytes)"
fi

URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"

download_with_curl() {
  for ATTEMPT in $(seq 1 40); do
    echo "Download attempt $ATTEMPT/40"
    curl --http1.1 -L --fail --continue-at - --retry 5 --retry-delay 2 --retry-all-errors --progress-bar \
      -o "$MODEL" \
      "$URL" && return 0

    SIZE="$(stat -f%z "$MODEL" 2>/dev/null || echo 0)"
    echo "Download interrupted at $SIZE bytes; retrying..."
    sleep 3
  done
  return 1
}

if command -v aria2c >/dev/null 2>&1; then
  aria2c \
    --continue=true \
    --max-connection-per-server=1 \
    --split=1 \
    --min-split-size=8M \
    --file-allocation=none \
    --retry-wait=3 \
    --max-tries=40 \
    --dir="$(dirname "$MODEL")" \
    --out="$(basename "$MODEL")" \
    "$URL" || download_with_curl
else
  download_with_curl
fi

SIZE="$(stat -f%z "$MODEL")"
if [ "$SIZE" -lt "$MIN_BYTES" ] || [ -f "$MODEL.aria2" ]; then
  echo "Downloaded file looks incomplete: $MODEL ($SIZE bytes)"
  exit 1
fi

echo "Downloaded: $MODEL"
