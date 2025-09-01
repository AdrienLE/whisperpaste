#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  echo "[install] This script only supports macOS (Darwin)." >&2
  exit 1
fi

APP_NAME="WhisperPaste"
PKG_DIR="dist/${APP_NAME}.app"
DEST_DIR="${HOME}/Applications"
DEST_APP="${DEST_DIR}/${APP_NAME}.app"

echo "[install] Packaging ${APP_NAME}…"
./scripts/package_app.sh

echo "[install] Installing to ${DEST_DIR}…"
mkdir -p "${DEST_DIR}"
rm -rf "${DEST_APP}"
cp -R "${PKG_DIR}" "${DEST_DIR}/"

echo "[install] Launching ${DEST_APP}…"
open "${DEST_APP}"

echo "[install] Done. Next runs will use the installed app: ${DEST_APP}"

