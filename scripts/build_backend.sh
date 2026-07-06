#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/bin"

cd "$ROOT/backend"
go build -trimpath -ldflags="-s -w" -o "$ROOT/bin/captionflow-backend" ./cmd/movknown-backend

echo "Built: $ROOT/bin/captionflow-backend"
