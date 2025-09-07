#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")/.."
OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  echo "[run] This app can only run on macOS (Darwin)." >&2
  exit 1
fi
echo "[run] Preparing dev tray icon (trim tight, grayscale)..."
cd App/.. || exit 1
ICON_SRC="icon.png"
DEV_ICON_DIR="dist/.dev_icon"
STATUS_ICON_1X="$DEV_ICON_DIR/statusIconTemplate.png"
STATUS_ICON_2X="$DEV_ICON_DIR/statusIconTemplate@2x.png"
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
    # 0% padding: center on tight square canvas only (no extra extent)
    # Tight square, grayscale, make near-white transparent; thicken at full res, then downscale crisply and sharpen
    DILATE_KERNEL="${WP_TRAY_DILATE:-Octagon:7}"
    echo "[run] Tray thickness kernel: ${DILATE_KERNEL}"
    # Generate both 1x (18pt) and 2x (36pt) status icons to match packaged app fidelity
    "${IM_CONVERT[@]}" "$DEV_ICON_DIR/trim.png" -background none -gravity center -extent ${SIDE}x${SIDE} -colorspace Gray -alpha on -fuzz 5% -transparent white -channel A -morphology Dilate $DILATE_KERNEL +channel -resize 18x18 "$STATUS_ICON_1X" || true
    "${IM_CONVERT[@]}" "$DEV_ICON_DIR/trim.png" -background none -gravity center -extent ${SIDE}x${SIDE} -colorspace Gray -alpha on -fuzz 5% -transparent white -channel A -morphology Dilate $DILATE_KERNEL +channel -resize 36x36 "$STATUS_ICON_2X" || true
  else
    # Fallback: basic resize; template rendering by macOS will tint it
    sips -s format png -z 18 18 "$ICON_SRC" --out "$STATUS_ICON_1X" >/dev/null || true
    sips -s format png -z 36 36 "$ICON_SRC" --out "$STATUS_ICON_2X" >/dev/null || true
  fi
  export WP_STATUS_ICON_PATH="$STATUS_ICON_1X"
  export WP_STATUS_ICON_PATH_1X="$STATUS_ICON_1X"
  export WP_STATUS_ICON_PATH_2X="$STATUS_ICON_2X"
fi

echo "[run] Building and launching WhisperpasteApp..."
cd App && swift run -c release WhisperpasteApp
