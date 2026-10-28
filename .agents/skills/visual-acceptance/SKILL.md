---
name: visual-acceptance
description: Capture, inspect and attach iOS simulator screenshots or videos to pull requests. Use for user-visible features and UI fixes before merge or TestFlight deployment.
---

# Visual acceptance

Use this workflow for explicitly requested UI verification or captures. Duo UI journeys are manual opt-in only; do not dispatch them or hold ordinary PRs for UI screenshots. When captures are requested, show the reviewed result while the PR is open, then refresh it only if the UI changes later.

- **Show:** capture the feature or fix described in the PR from its current code. Add UI-test steps that screenshot the new state if no existing journey reaches it.
- **Limit:** use 1–3 screenshots by default. Skip duplicates and unrelated screens.
- **Video:** only when the change is motion itself (an animation or transition) and screenshots can't show it. Don't record or review video otherwise.
- **Check:** confirm that the screenshots show the requested behavior and display clearly in the PR. Publish requested CI evidence with `scripts/pr-visual-evidence.py`; link reviewed native captures directly for a native screenshot task.
- **Clean up:** remove temporary downloads after publishing.
- **Device panels:** close task-owned connections as soon as interactive verification finishes, fails or is handed off. State the check and purpose while a connection stays open. Leave a shared simulator running unless shutdown is requested or it was created solely for this task.

For non-UI changes, report the functional checks instead.
