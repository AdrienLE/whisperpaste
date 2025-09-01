#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="WhisperPaste"
APP_DIR="dist/${APP_NAME}.app"
BIN_PATH="$(cd App && swift build -c release --show-bin-path)"
BIN="${BIN_PATH}/Whisper2App"

echo "[package] Building SwiftPM app binary..."
(cd App && swift build -c release)

echo "[package] Creating app bundle at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

ICON_SRC="icon.png"
ICON_WORK_DIR="dist/.icon_work"
ICONSET_DIR="${ICON_WORK_DIR}/AppIcon.iconset"
ICON_PROCESSED="${ICON_WORK_DIR}/processed.png"
ICNS_OUT="${APP_DIR}/Contents/Resources/AppIcon.icns"
STATUS_OUT1="${APP_DIR}/Contents/Resources/statusIconTemplate.png"
STATUS_OUT2="${APP_DIR}/Contents/Resources/statusIconTemplate@2x.png"

if [[ -f "$ICON_SRC" ]]; then
  echo "[package] Preparing icon assets from ${ICON_SRC} (trim + 5% padding)..."
  rm -rf "$ICON_WORK_DIR" && mkdir -p "$ICONSET_DIR"
  # Use ImageMagick if available to trim transparent margins and add ~5% padding.
  if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    if command -v magick >/dev/null 2>&1; then IM="magick"; else IM="convert"; fi
    # Trim transparent edges
    $IM "$ICON_SRC" -alpha on -trim +repage "${ICON_WORK_DIR}/trimmed.png"
    # Measure trimmed size
    if command -v identify >/dev/null 2>&1; then
      read W H < <(identify -format "%w %h" "${ICON_WORK_DIR}/trimmed.png")
    else
      read W H < <($IM identify -format "%w %h" "${ICON_WORK_DIR}/trimmed.png")
    fi
    if [[ -z "$W" || -z "$H" ]]; then W=1024; H=1024; fi
    if (( W > H )); then SIDE=$W; else SIDE=$H; fi
    PAD_SIDE=$(( (SIDE * 105 + 99) / 100 ))
    # Center on transparent square canvas, then add ~5% padding
    $IM "${ICON_WORK_DIR}/trimmed.png" -background none -gravity center -extent ${SIDE}x${SIDE} -extent ${PAD_SIDE}x${PAD_SIDE} "$ICON_PROCESSED"
  else
    echo "[package] ImageMagick not found; using raw icon without trimming."
    cp -f "$ICON_SRC" "$ICON_PROCESSED"
  fi
  echo "[package] Generating .icns and status bar icons..."
  # Build iconset at required sizes from processed icon
  sips -z 16 16   "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32   "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32   "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64   "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_PROCESSED" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUT"
  else
    echo "[package] iconutil not found; skipping .icns generation"
  fi
  # Generate grayscale template status bar icon (18pt and 2x)
  sips -s format png -s colorModel Gray -z 18 18  "$ICON_PROCESSED" --out "$STATUS_OUT1" >/dev/null
  sips -s format png -s colorModel Gray -z 36 36  "$ICON_PROCESSED" --out "$STATUS_OUT2" >/dev/null
else
  echo "[package] ${ICON_SRC} not found; skipping icon generation"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>WhisperPaste</string>
  <key>CFBundleExecutable</key>
  <string>WhisperPaste</string>
  <key>CFBundleIdentifier</key>
  <string>local.whisperpaste</string>
  <key>CFBundleName</key>
  <string>WhisperPaste</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>WhisperPaste needs microphone access to record your dictation.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>WhisperPaste uses speech recognition for live preview.</string>
</dict>
</plist>
PLIST

cp -f "${BIN}" "${APP_DIR}/Contents/MacOS/WhisperPaste"
chmod +x "${APP_DIR}/Contents/MacOS/WhisperPaste"
echo "APPL????" > "${APP_DIR}/Contents/PkgInfo"

echo "[package] Packaged app: ${APP_DIR}"
echo "Use: open \"${APP_DIR}\" to launch."
