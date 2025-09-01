#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  echo "[run] This app can only run on macOS (Darwin)." >&2
  exit 1
fi
echo "[run] Preparing dev tray icon (trim + 5% padding, grayscale)..."
cd App/.. || exit 1
ICON_SRC="icon.png"
DEV_ICON_DIR="dist/.dev_icon"
STATUS_ICON="$DEV_ICON_DIR/statusIconTemplate.png"
mkdir -p "$DEV_ICON_DIR"
if [[ -f "$ICON_SRC" ]]; then
  if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 || command -v identify >/dev/null 2>&1; then
    # Choose ImageMagick entrypoint
    if command -v magick >/dev/null 2>&1; then IM_CONVERT=(magick); IM_IDENTIFY=(magick identify); 
    else IM_CONVERT=(convert); IM_IDENTIFY=(identify); fi
    "${IM_CONVERT[@]}" "$ICON_SRC" -alpha on -trim +repage "$DEV_ICON_DIR/trim.png" || true
    # Capture dimensions without aborting on failure
    DIMS=$("${IM_IDENTIFY[@]}" -format "%w %h" "$DEV_ICON_DIR/trim.png" 2>/dev/null || true)
    W=$(echo "$DIMS" | awk '{print $1}')
    H=$(echo "$DIMS" | awk '{print $2}')
    [[ -z "$W" || -z "$H" ]] && W=1024 && H=1024
    if (( W > H )); then SIDE=$W; else SIDE=$H; fi
    PAD_SIDE=$(( (SIDE * 105 + 99) / 100 ))
    "${IM_CONVERT[@]}" "$DEV_ICON_DIR/trim.png" -background none -gravity center -extent ${SIDE}x${SIDE} -extent ${PAD_SIDE}x${PAD_SIDE} -colorspace Gray -resize 18x18 "$STATUS_ICON" || true
  else
    # Fallback: basic grayscale + resize
    sips -s format png -s colorModel Gray -z 18 18 "$ICON_SRC" --out "$STATUS_ICON" >/dev/null || true
  fi
  export WP_STATUS_ICON_PATH="$STATUS_ICON"
fi

echo "[run] Building and launching Whisper2App..."
cd App && swift run -c release Whisper2App
