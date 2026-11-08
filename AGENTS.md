## Standing Rules

- Write all GitHub-facing prose in English, including commit messages, code comments, PR and issue titles and descriptions, review comments, discussions, and release notes.
- Deliver changes with the `full-send` skill in `.agents/skills/`: its roles, merge gate, bot-review and CI-budget rules apply to every PR, including PR-only work.
- On Linux, validate iOS changes through the PR's macOS build/unit CI. If the developer explicitly requested UI verification, inspect its exported screenshots with `scripts/pr-evidence.sh PR_NUMBER`, fix concrete failures on the same PR, and remove downloaded evidence after review.
- Simulators: every simulator run, test, capture or Device panel follows the Fleet `simulator-queue` skill (`~/myai/fleet/skills/simulator-queue/SKILL.md`), which is shared by all projects: which device, how to reach MacPro from Linux, the queue, the cloud fallback and cleanup. `scripts/simulator-app.sh [PR_NUMBER]` prints the CI simulator build for a PR head, or for master without an argument; the `visual-acceptance` skill has what GrowingUp itself needs.
- Duo UI journeys are manual opt-in only: `gh workflow run ci.yml --ref BRANCH -f run_duo_ui_tests=true`. Run them only when the developer explicitly requests UI tests or captures. Routine PRs and master pushes must not launch them or wait for their screenshots before merge.
- App Store screenshots are never captured on CI. They are shot on MacPro with the `app-store-screenshots` skill and committed; `app-store-metadata.yml` only inspects App Store Connect or places those committed sets.
- When UI verification is requested, publish 1–3 reviewed screenshots while the PR is open. Use `scripts/pr-visual-evidence.py` for requested CI evidence, or link reviewed native captures from the requested capture task. Use video only when the change is motion itself. Otherwise report functional checks.
- A requested TestFlight release continues after merge: dispatch it immediately for the selected merged SHA, share its live Actions URL and phase, and retain the run/receipt identity. A merged PR or completed agent turn is not a completed release; PR watches do not monitor TestFlight. Use `scripts/testflight.py progress RUN_ID` for read-only status.
- Close task-owned Device panel connections after interactive verification, on failure and before handoff. Keep one open only for an explicitly stated active check or at the user's request.

## CI and pushing

GitHub's macOS runners are shared by all of Danis's repositories (about five at a time), so every push waits behind other work. A PR push runs one macOS job (Build & Test) plus Linux checks; Release Tools adds a second only when fastlane, Gemfile, project, plist, entitlement or workflow files change. Docs, skills and store-media changes skip the iOS checks.

- **Push batches, not commits.** Commit locally as often as useful; push when a batch is ready for CI or review: the first push opens the PR, and review fixes go out together in one push. A draft PR runs the same CI, so don't push work in progress just to save it.
- **Check locally first; CI should confirm, not discover.** Before a push that touches Swift, run `scripts/check-formatting.sh` and `scripts/lint-swift.sh`; on Linux, Swift 6.4 comes from `swiftly` and SwiftLint from `scripts/install-swiftlint.sh`, the same versions CI uses. Before any push, run `python3 -m unittest discover -s scripts/tests` and `scripts/check-secrets.sh`.
- **Iterate on compile errors and failing unit tests on MacPro, not by pushing.** From Linux, copy the worktree without `marketing/` to a scratch directory over `ssh macpro.remote` (rsync), build there with `xcodebuild build-for-testing`, and delete the directory afterwards. A build takes no simulator slot but counts toward MacPro's health; running the tests takes the slot. The `simulator-queue` skill covers both; use `-only-testing` for the touched classes. Push once the build and those tests pass.
- **Heavy jobs only on request:** Duo UI journeys (above); the Simulator App build, which `scripts/simulator-app.sh` dispatches itself when an agent needs the app; TestFlight, only when a release is authorized. Never rerun a green job for an unchanged commit; superseded runs on the same branch cancel themselves.

## Code Style

- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Declare only one type per Swift file; direct extensions of that file's primary type are the only exception.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
