#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  echo "[run] This app can only run on macOS (Darwin)." >&2
  exit 1
fi
echo "[run] Building and launching Whisper2App..."
cd App && swift run -c release Whisper2App
