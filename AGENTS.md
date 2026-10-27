## Standing Rules

- Deliver changes with the `full-send` skill in `.agents/skills/`: its roles, merge gate, bot-review and CI-budget rules apply to every PR, including PR-only work.
- On Linux, validate iOS changes through the PR's macOS CI and `scripts/pr-evidence.sh PR_NUMBER`. Inspect the exported screenshots for the latest head, fix concrete failures on the same PR, and remove downloaded evidence after review.
- To drive the app interactively from Linux, install the CI simulator build on an Expo cloud simulator with the `eas-simulator` skill: `scripts/simulator-app.sh [PR_NUMBER]` prints the `.app` path for a PR head, or for master without an argument.
- For user-visible changes, publish 1–3 reviewed CI screenshots with `scripts/pr-visual-evidence.py` while the PR is open. Use video only when the change is motion itself. For non-UI changes, report functional checks instead.
- A requested TestFlight release continues after merge: dispatch it immediately for the selected merged SHA, share its live Actions URL and phase, and retain the run/receipt identity. A merged PR or completed agent turn is not a completed release; PR watches do not monitor TestFlight. Use `scripts/testflight.py progress RUN_ID` for read-only status.
- Close task-owned Device panel connections after interactive verification, on failure and before handoff. Keep one open only for an explicitly stated active check or at the user's request.

## Code Style

- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Declare only one type per Swift file; direct extensions of that file's primary type are the only exception.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
