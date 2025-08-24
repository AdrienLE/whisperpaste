#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Whisper2"
APP_DIR="dist/${APP_NAME}.app"
BIN_PATH="$(cd App && swift build -c release --show-bin-path)"
BIN="${BIN_PATH}/Whisper2App"

echo "[package] Building SwiftPM app binary..."
(cd App && swift build -c release)

echo "[package] Creating app bundle at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Whisper2</string>
  <key>CFBundleExecutable</key>
  <string>Whisper2</string>
  <key>CFBundleIdentifier</key>
  <string>local.whisper2</string>
  <key>CFBundleName</key>
  <string>Whisper2</string>
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
  <string>Whisper2 needs microphone access to record your dictation.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>Whisper2 uses speech recognition for live preview.</string>
</dict>
</plist>
PLIST

cp -f "${BIN}" "${APP_DIR}/Contents/MacOS/Whisper2"
chmod +x "${APP_DIR}/Contents/MacOS/Whisper2"
echo "APPL????" > "${APP_DIR}/Contents/PkgInfo"

echo "[package] Packaged app: ${APP_DIR}"
echo "Use: open \"${APP_DIR}\" to launch."

