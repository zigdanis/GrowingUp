## Standing Rules

- Deliver changes with the `full-send` skill in `.agents/skills/`: its roles, merge gate, bot-review and CI-budget rules apply to every PR, including PR-only work.
- On Linux, validate iOS changes through the PR's macOS build/unit CI. If the developer explicitly requested UI verification, inspect its exported screenshots with `scripts/pr-evidence.sh PR_NUMBER`, fix concrete failures on the same PR, and remove downloaded evidence after review.
- To drive the app interactively from Linux, follow the `cloud-simulator` skill in `.agents/skills/`: it installs the CI simulator build from `scripts/simulator-app.sh [PR_NUMBER]` on an Expo cloud simulator.
- Duo UI journeys are manual opt-in only: `gh workflow run ci.yml --ref BRANCH -f run_duo_ui_tests=true`. Run them only when the developer explicitly requests UI tests or captures. Routine PRs and master pushes must not launch them or wait for their screenshots before merge. App Store screenshot capture remains manual.
- When UI verification is requested, publish 1–3 reviewed screenshots while the PR is open. Use `scripts/pr-visual-evidence.py` for requested CI evidence, or link reviewed native captures from the requested capture task. Use video only when the change is motion itself. Otherwise report functional checks.
- A requested TestFlight release continues after merge: dispatch it immediately for the selected merged SHA, share its live Actions URL and phase, and retain the run/receipt identity. A merged PR or completed agent turn is not a completed release; PR watches do not monitor TestFlight. Use `scripts/testflight.py progress RUN_ID` for read-only status.
- Close task-owned Device panel connections after interactive verification, on failure and before handoff. Keep one open only for an explicitly stated active check or at the user's request.

## Code Style

- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Declare only one type per Swift file; direct extensions of that file's primary type are the only exception.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
