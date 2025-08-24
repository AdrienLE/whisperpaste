#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  echo "[build] Building app (App package) in release..."
  (cd App && swift build -c release)
else
  echo "[build] Non-macOS host detected. Building core library only..."
  swift build -c release --target Whisper2Core
fi
