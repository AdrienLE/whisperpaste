# WhisperPaste (macOS Menu Bar App)

WhisperPaste is a macOS menu bar app for fast dictation: click the status item (or use a global hotkey) to start recording with a live preview, then transcribe with OpenAI and optionally clean up text before it’s copied to your clipboard and stored in history.

Key features
- Live preview while speaking (Apple Speech).
- Transcription via OpenAI Whisper or compatible “transcribe” models.
- Optional cleanup via a GPT chat model (punctuation/grammar/paragraphs), configurable prompt.
- New: use transcription-only mode with a separate “Transcription Prompt” to speed things up.
- Compact popover with recording indicator, status, and a Copy button for the last result.
- History window with preview/transcribed/cleaned text and audio references.
- Model list refresh + filtering (hides preview/two-digit variants by default); “Show all models” toggle.
- Benchmark window to compare model speeds (transcribe and cleanup).
- Small, trimmed monochrome tray icon with custom branding.

Requirements
- macOS 12+
- Xcode (or CLT) with Swift 5.7+

Install / Run
- Dev (SwiftPM):
  - `./scripts/build_and_run.sh`
  - This generates a dev tray icon and launches the app.
- Packaged app:
  - `./scripts/run_app.sh`
  - Produces `dist/WhisperPaste.app` with proper icons and usage descriptions.

Settings
- Enter your OpenAI API key.
- Choose a Transcription Model and optionally a Transcription Prompt (sent to the transcribe endpoint).
- Toggle “Enable cleanup (chat model)” to show the Cleanup Model and Cleanup Prompt.
- “Show all models” reveals preview/two-digit variants; hidden by default.
- “Keep audio files” controls whether recorded audio is retained in `~/Library/Application Support/whisperpaste/audio/`.

Privacy / Storage
- Settings and history live under `~/Library/Application Support/whisperpaste/` (falls back to legacy `whisper2/` if present).
- Audio is compressed to low-bitrate AAC (M4A) by default to reduce upload size.
- The API key is stored in local JSON (insecure placeholder). Consider migrating to Keychain for production.

Scripts
- `scripts/test.sh`: Runs unit tests for the core library.
- `scripts/run.sh`: Builds and runs via SwiftPM with a dev tray icon.
- `scripts/build_and_run.sh`: Tests + run.
- `scripts/build.sh`: Release build (SPM).
- `scripts/package_app.sh`: Packages a `.app` bundle in `dist/WhisperPaste.app`.

Development notes
- Core logic lives in `Whisper2Core` (models, storage, utilities) with unit tests.
- UI is AppKit-based; live preview uses AVAudioEngine + SFSpeechRecognizer.
- OpenAI calls are synchronous wrappers inside a background queue for simplicity.
- See `PLAN.md` for roadmap, `AGENTS.md` for contribution/commit guidelines.

License
This project is licensed under the MIT License — see `LICENSE`.

## Requirements
- macOS 12+
- Xcode (or Command Line Tools) with Swift 5.7+

## Scripts
- `scripts/test.sh`: Runs unit tests for the core library.
- `scripts/build.sh`: Builds the app (SPM executable) in release mode.
- `scripts/run.sh`: Builds and runs the app.
- `scripts/build_and_run.sh`: Runs tests, then builds and runs.
- `scripts/package_app.sh`: Packages a proper macOS `.app` bundle with Info.plist (Mic + Speech usage descriptions). Launch it with `open dist/Whisper2.app`.

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
- Live preview uses Apple Speech (SFSpeechRecognizer) with AVAudioEngine. For reliable permission prompts, prefer the packaged app (`package_app.sh`) so the system sees usage descriptions.
- OpenAI transcription + cleanup run after you stop recording. You must set your API key in Settings. Model dropdowns can be refreshed via the API.

See `PLAN.md` for the roadmap and `AGENTS.md` for contribution/commit guidelines.
