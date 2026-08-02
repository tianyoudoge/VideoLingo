#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CAPTIONFLOW_BACKEND="${CAPTIONFLOW_BACKEND:-$ROOT/bin/captionflow-backend}"
export CAPTIONFLOW_WHISPER_MODEL="${CAPTIONFLOW_WHISPER_MODEL:-$ROOT/models/ggml-large-v3-q5_0.bin}"
export CAPTIONFLOW_VAD_MODEL="${CAPTIONFLOW_VAD_MODEL:-$ROOT/models/ggml-silero-v6.2.0.bin}"
export CAPTIONFLOW_WHISPER_BIN="${CAPTIONFLOW_WHISPER_BIN:-$ROOT/bin/whisper-cli}"

swift run --package-path "$ROOT/app" CaptionFlowApp
