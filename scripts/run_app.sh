#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/package_app.sh
open dist/Whisper2.app

