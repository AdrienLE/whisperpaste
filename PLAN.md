# Plan: WhisperPaste Menu Bar App

Status: In Progress — core, UI, live preview, pipeline, hotkey, playback implemented; packaging/script flow stable

Goals
- Ship a macOS menu bar app for dictation with live preview (Apple Speech), full transcription (OpenAI Whisper or equivalent), and cleanup (GPT), plus Settings, History, and a tray menu.

Phases
1) Skeleton + Core (done)
   - SPM workspace with `WhisperpasteCore` (models, storage) + tests.
   - Menu bar app stub with left-click toggle + popover, right-click menu.
   - Basic Settings/History window stubs.
   - Build/run/test scripts.
   - Git initialized (commits tied to plan updates).

2) App Bundle Migration (partial)
   - SwiftPM-based menu bar app works; added `scripts/package_app.sh` to create a `.app` bundle with Info.plist (Mic + Speech usage descriptions) [done].
   - Optional: migrate to Xcode project for entitlements/notarization [pending].
   - Apple live transcription (AVAudioEngine + SFSpeechRecognizer) for preview [done].

3) Recording + Storage (done)
   - Record audio to disk (CAF/WAV→M4A) with retention setting (keep/auto-clean) and cleanup tools.
   - Robust, resumable storage of audio and history metadata.

4) OpenAI Integrations (done)
   - Transcription via OpenAI API (configurable model) [implemented].
   - Cleanup via GPT with customizable prompt [implemented].
   - Settings UI for API key, models, prompt, and hotkey [implemented].
   - Fetch model list dynamically from OpenAI API (Refresh Models) [implemented].
   - Persist fetched model lists; auto-refresh on first open of Settings; avoid hardcoded defaults when lists are available [added].

5) UX Polish (in progress)
   - Popover live text, progress, and error handling [in place].
   - History list with copy raw/cleaned and audio playback; handle missing audio gracefully [implemented].
   - Global hotkey support (customizable) [implemented and verified in packaged app].
   - Dock icon only while Settings is open [added].
   - Live preview auto-scroll and animated in-progress indicator during recording [added].

6) Tests + QA
   - Unit tests for storage, hotkey parsing, and path helpers [added].
   - Integration tests for transcription pipeline (mock network) [pending].

Current Status (as of this update)
- Implemented: menu bar app, live preview (Apple Speech), OpenAI transcription + cleanup pipeline, Settings (editable + Save closes), History with audio playback, dynamic model fetch, hotkey recorder UI + global hotkey manager, packaging script for `.app`.
- Permissions: For reliable mic/speech prompts, use the packaged app (`scripts/package_app.sh` then `open dist/WhisperPaste.app`).
- Known issues: Building the `App` SwiftPM package in this environment can fail due to sandbox/caches. Use the packaged app (`scripts/package_app.sh`) to verify runtime features.

Bug Fixes (2025-08-25)
- Live Preview readability: switched preview editor to a true read-only presentation (no border/background, no first responder), and unified text coloring to `labelColor` to ensure dark-mode visibility within popovers.
- Cleanup Prompt visibility (dark mode): removed custom text/insertion/typing color overrides in the multiline editor and now rely on system default colors. This makes the prompt text visible in dark mode and avoids over-customization.
- Settings layout polish: aligned Cleanup Prompt with other rows (label column, full-width editor), moved “Refresh Models” to bottom action bar next to new Cancel and existing Save buttons.

Bug Fixes (2025-08-31)
- Invisible text in preview and prompt: fixed `NSTextView` embedding by sizing the document view to the scroll view’s content size and enabling `textContainer.widthTracksTextView` + large container height. This resolves the zero-width/zero-height layout that made text effectively invisible.
- Undo/Redo in prompt editor: enabled `textView.allowsUndo = true` in editable mode so Cmd+Z/Cmd+Shift+Z work as expected.
- Minor: ensured the text view is vertically resizable with an unbounded container size to prevent clipping.
- Prompt editor scrolling: adjusted layout to set document width to the scroll view while letting height expand to the content’s used rect; the document height now exceeds the viewport when needed, enabling vertical scrolling.
 - Live preview auto-scroll during recording: added `autoScrollToEnd` behavior in the read-only editor and trigger scrolling as content grows.
 - Recording UI stability: keep Stop button space reserved (alpha toggle) to avoid layout jumps when entering/leaving recording.
- Indicator polish: switched to animated three dots (no leading big dot) and colored with accent color for visibility.
- Cleanup HTTP 400: removed `temperature` from cleanup API calls because some models only accept the default; avoids unsupported-parameter errors.

Next Steps
- Release v1.0:
  - Docs: finalize README (hotkey, playback, install, known limitations); add RELEASE.md checklist.
  - Packaging: allow version via env (WP_VERSION/WP_BUILD) in `package_app.sh`.
  - Tag: create `v1.0.0` after QA.
  - Optional: Xcode project for entitlements/signing and notarization if distributing.

Pause Note
- Work continues; global hotkey and playback verified in packaged app. Use `scripts/package_app.sh` and run from `dist/` for proper permissions prompts.

Today’s Progress
- Initialized skeleton (core library + tests, menu bar stub, scripts).
- Next: migrate to app bundle and enable Apple live transcription.

Renames (2025-09-01)
- Standardized naming from whisper2 → whisperpaste across packages, module, app target, scripts, and docs. Core module is now `WhisperpasteCore`, app executable `WhisperpasteApp`, and root SwiftPM package `whisperpaste`. Legacy `~/Library/Application Support/whisper2/` remains supported for migration.

Build/Packaging Fix (2025-09-04)
- Resolved PCH/module cache path mismatch after moving the repo directory (e.g., whisper2 → whisperpaste), which manifested as “PCH was compiled with module cache path …” and “missing required module 'SwiftShims'”.
- scripts/package_app.sh now cleans the App package before any build and only resolves the binary path after a successful build. Specifically: runs `swift package clean`, removes `App/.build`, then builds. This ensures stale ModuleCache entries don’t leak across paths.
- Action: use `scripts/install_app.sh` or `scripts/package_app.sh` again; the scripts will clean and rebuild in the new path.

Bug Fix (2025-09-04)
- History: Fixed `HistoryWindowController.keyDown(with:)` declaration. It now correctly overrides `NSResponder.keyDown` and is not `private`, resolving “overriding instance method must be as accessible as its enclosing type” and missing `override` errors. Also switched a never-mutated `var` to `let`.

Security Change (2025-09-07)
- Per request, removed Keychain usage for the OpenAI API key. The key is now stored directly in `Settings.openAIKey` (JSON under `~/Library/Application Support/whisperpaste/settings.json`). Updated Settings UI, MenuBar checks, and README. Dropped the `Security` framework and deleted `Keychain.swift`.

Recording Reliability (2025-09-07)
- Added verbose `NSLog` tracing around the recording lifecycle (start/auth/mic access/configure/start/stop) to debug “second recording” failures.
- On stop, call `engine.reset()` after `engine.stop()` and log finish details. This can help release audio resources for subsequent sessions.

Build Fix (2025-09-14)
- Resolved compile errors due to missing `SettingsWindowController.filteredModels` after refactor to core utility.
- Replaced all call sites with `ModelFiltering.filtered` in Settings and Benchmark windows, consolidating filtering logic in `WhisperpasteCore`.
- Verified by running `scripts/test.sh` (all tests pass).
