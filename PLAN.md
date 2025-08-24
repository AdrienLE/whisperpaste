# Plan: Whisper2 Menu Bar App

Status: Phase 1 — Project Skeleton (this commit)

Goals
- Ship a macOS menu bar app for dictation with live preview (Apple Speech), full transcription (OpenAI Whisper or equivalent), and cleanup (GPT), plus Settings, History, and a tray menu.

Phases
1) Skeleton + Core (now)
   - SPM workspace with `Whisper2Core` (models, storage) + tests.
   - Menu bar app stub with left-click toggle + popover, right-click menu.
   - Basic Settings/History window stubs.
   - Build/run/test scripts.
   - Git initialized (commits tied to plan updates).

2) App Bundle Migration
   - Convert SPM executable into a proper macOS app bundle (Xcode project).
   - Add Info.plist with `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`.
   - Wire Apple live transcription (AVAudioEngine + SFSpeechRecognizer) for preview.

3) Recording + Storage
   - Record audio to disk (CAF/WAV) with retention setting (keep/auto-clean) and cleanup tools.
   - Robust, resumable storage of audio and history metadata.

4) OpenAI Integrations
   - Transcription via OpenAI API (configurable model).
   - Cleanup via GPT with customizable prompt.
   - Settings UI for API key, models, prompt, and hotkey.

5) UX Polish
   - Popover live text, progress, and error handling.
   - History list with copy raw/cleaned, reveal/play audio, missing-audio handling.
   - Global hotkey support (customizable).

6) Tests + QA
   - Unit tests for storage, model selection, prompt handling.
   - Integration tests for transcription pipeline (mocked).

Today’s Progress
- Initialized skeleton (core library + tests, menu bar stub, scripts).
- Next: migrate to app bundle and enable Apple live transcription.
