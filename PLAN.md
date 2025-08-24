# Plan: Whisper2 Menu Bar App

Status: In Progress — core, UI, live preview, and pipeline implemented; hotkey + packaging ongoing

Goals
- Ship a macOS menu bar app for dictation with live preview (Apple Speech), full transcription (OpenAI Whisper or equivalent), and cleanup (GPT), plus Settings, History, and a tray menu.

Phases
1) Skeleton + Core (done)
   - SPM workspace with `Whisper2Core` (models, storage) + tests.
   - Menu bar app stub with left-click toggle + popover, right-click menu.
   - Basic Settings/History window stubs.
   - Build/run/test scripts.
   - Git initialized (commits tied to plan updates).

2) App Bundle Migration (partial)
   - SwiftPM-based menu bar app works; added `scripts/package_app.sh` to create a `.app` bundle with Info.plist (Mic + Speech usage descriptions) [done].
   - Optional: migrate to Xcode project for entitlements/notarization [pending].
   - Apple live transcription (AVAudioEngine + SFSpeechRecognizer) for preview [done].

3) Recording + Storage
   - Record audio to disk (CAF/WAV) with retention setting (keep/auto-clean) and cleanup tools.
   - Robust, resumable storage of audio and history metadata.

4) OpenAI Integrations (in progress)
   - Transcription via OpenAI API (configurable model) [implemented].
   - Cleanup via GPT with customizable prompt [implemented].
   - Settings UI for API key, models, prompt, and hotkey [implemented].
   - Fetch model list dynamically from OpenAI API (Refresh Models) [implemented].

5) UX Polish (in progress)
   - Popover live text, progress, and error handling [in place].
   - History list with copy raw/cleaned, reveal/play audio, missing-audio handling [basic copy implemented; reveal/play pending].
   - Global hotkey support (customizable) [hotkey recorder + Carbon registration added; needs verification under packaged app].

6) Tests + QA
   - Unit tests for storage, hotkey parsing, and path helpers [added].
   - Integration tests for transcription pipeline (mock network) [pending].

Current Status (as of this update)
- Implemented: menu bar app, live preview (Apple Speech), OpenAI transcription + cleanup pipeline, Settings (editable + Save closes), History, dynamic model fetch, hotkey recorder UI, basic global hotkey manager, packaging script for `.app`.
- Permissions: For reliable mic/speech prompts, use the packaged app (`scripts/package_app.sh` then `open dist/Whisper2.app`).
- Known issues: Building the `App` SwiftPM package in this environment sporadically fails after linking Carbon (for global hotkeys). Tests for `Whisper2Core` continue to pass. To resolve, test via the packaged app and/or migrate to an Xcode project for full control over entitlements and linking.

Next Steps
- Verify global hotkey registration end-to-end in the packaged app; update icon state and popover accordingly.
- Add “Reveal in Finder” and playback in History; handle missing audio gracefully.
- Improve error surfaces (network failures, permission denials) with inline UI messages.
- Optional: Migrate to an Xcode project (app target) with entitlements and signing; set up a simple CI for tests.
- Add integration tests with stubbed OpenAI client; add unit tests for model filtering and settings migrations.

Pause Note
- Work paused mid-task while verifying Carbon-based hotkey build under SwiftPM; resume by packaging the app (`scripts/package_app.sh`) and testing hotkeys, or by creating an Xcode app target for more reliable system integration.

Today’s Progress
- Initialized skeleton (core library + tests, menu bar stub, scripts).
- Next: migrate to app bundle and enable Apple live transcription.
