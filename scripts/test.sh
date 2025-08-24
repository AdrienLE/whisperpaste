#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "[tests] Running Swift Package tests..."
swift test --parallel

