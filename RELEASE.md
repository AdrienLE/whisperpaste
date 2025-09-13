WhisperPaste v1.0 Release Checklist

Preflight
- Run tests: `./scripts/test.sh` (all green).
- Ensure `icon.png` exists (optional, improves app/icon fidelity).
- Confirm OpenAI API key is set in Settings during manual QA.

Package
- Build packaged app with version/build:
  - `WP_VERSION=1.0.0 WP_BUILD=1 ./scripts/package_app.sh`
- Optional install to `~/Applications`:
  - `./scripts/install_app.sh`

Manual QA (packaged app from `dist/` or `~/Applications`)
- Permissions: first launch requests Mic/Speech (when recording); app shows in menu bar.
- Hotkey: press to start/stop recording; popover opens and stays visible during processing.
- Recording: live preview text appears while speaking.
- Transcribe: stop recording; transcription runs; if cleanup enabled, cleanup runs after.
- Final text: auto‑copied to clipboard; Copy button enabled and shows “Copied” state appropriately.
- Abort: while recording, use Abort — popover closes, UI resets, audio discarded.
- History: entries appear with preview/transcribed/cleaned text; per‑row play button plays audio if present.
- Clear All Audio: removes files from disk but keeps text; Clear History removes entries entirely.
- Settings: set API key, choose models, toggle cleanup/use transcription prompt; Refresh Models updates lists.
- Model lists: default filtering hides preview/time‑suffix variants; “Show all models” reveals full list.

Tag
- Create an annotated tag after QA:
  - `git tag -a v1.0.0 -m "WhisperPaste 1.0.0"`
  - `git push --follow-tags` (optional, when ready to publish)

Notes
- This skeleton stores the API key in settings JSON (insecure) — switch to Keychain for production.
- Notarization/signing: migrate to an Xcode app target if distributing widely.

