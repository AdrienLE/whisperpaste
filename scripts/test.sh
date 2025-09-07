#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Clean to avoid stale ModuleCache/PCH after path changes
echo "[tests] Cleaning package…"
swift package clean || true
rm -rf .build

echo "[tests] Running Swift Package tests..."
swift test --parallel
