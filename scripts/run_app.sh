#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VIDEOLINGO_BACKEND="${VIDEOLINGO_BACKEND:-$ROOT/bin/videolingo-backend}"
export VIDEOLINGO_WHISPER_MODEL="${VIDEOLINGO_WHISPER_MODEL:-$ROOT/models/ggml-medium.bin}"
export VIDEOLINGO_WHISPER_BIN="${VIDEOLINGO_WHISPER_BIN:-$ROOT/bin/whisper-cli}"

swift run --package-path "$ROOT/app" VideoLingoApp
