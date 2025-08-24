# Whisper2 (macOS Menu Bar App) — Skeleton

Whisper2 is a macOS-only menu bar app for dictation: left-click to start/stop recording with a live preview, then transcribe via OpenAI and clean up text via a GPT model. This commit provides a working project skeleton, a core library with tests, scripts to build/run/tests, and a simple menu bar stub (no mic/transcription yet). The full UI and integrations will be iterated per the plan.

## Requirements
- macOS 12+
- Xcode (or Command Line Tools) with Swift 5.7+

## Scripts
- `scripts/test.sh`: Runs unit tests for the core library.
- `scripts/build.sh`: Builds the app (SPM executable) in release mode.
- `scripts/run.sh`: Builds and runs the app.
- `scripts/build_and_run.sh`: Runs tests, then builds and runs.

Usage:

```bash
# from repo root
chmod +x scripts/*.sh
./scripts/test.sh
./scripts/run.sh
# or
./scripts/build_and_run.sh
```

Notes:
- The current SPM executable starts an NSApplication and creates a menu bar item; left-click toggles a popover with a live-preview placeholder and right-click opens a menu (Settings, History, Quit).
- Microphone capture and Apple live transcription are not enabled yet because they require an app bundle with Info.plist usage descriptions and entitlements. The next phase will migrate the app target to an Xcode app bundle and wire in AVAudio and Speech frameworks.
- OpenAI transcription + cleanup are stubbed and will be implemented once settings UI and on-disk storage solidify.

See `PLAN.md` for the roadmap and `AGENTS.md` for contribution/commit guidelines.
