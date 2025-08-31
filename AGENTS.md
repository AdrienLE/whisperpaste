# Agents Guide

Working Agreement
- Always update `PLAN.md` when scope or progress changes.
- Keep changes small, frequent, and focused. Write clear commit messages referencing the plan.
- Run `scripts/test.sh` before committing; only commit when tests pass and the app at least builds.
- After any successful change, run tests and commit the change with a clear message that references the related `PLAN.md` entry.
- If blocked (e.g., missing toolchain), push plan updates without committing risky changes and note blockers in the PR/commit message.

Coding Guidelines
- Keep the macOS focus; prefer native frameworks (AppKit/AVFoundation/Speech) where practical.
- Separate core logic (`Whisper2Core`) from UI; make the core testable.
- Defer network calls and external services behind protocol abstractions so they can be mocked in tests.
- Persist user settings/history under `~/Library/Application Support/whisper2/`.

Commit Triggers
- Modify `PLAN.md` to reflect current step and rationale.
- Commit after: model/storage changes, UI buildable state, script adjustments, or test additions.
- Avoid committing half-integrations (e.g., partial API calls) unless they are feature-flagged or mocked.

Security/Privacy
- Store API keys in Keychain in the app bundle phase; for the skeleton, only use local JSON for placeholders and clearly mark it as insecure.
- When handling audio, provide a “keep audio” toggle and cleanup utilities; handle missing audio gracefully in history.

CLI Hygiene
- Run commands sequentially rather than chaining with ';' or '&&' when approvals/sandboxing are in effect. Example:
  - Preferred: `git add -A` then `git commit -m "msg"` as two separate invocations.
  - Avoid: `git add -A; git commit -m "msg"`.
- This reduces repeated permission prompts and makes failures clearer.
