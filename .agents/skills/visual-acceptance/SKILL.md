---
name: visual-acceptance
description: Capture, inspect and attach iOS simulator screenshots or videos to pull requests. Use for user-visible features and UI fixes before merge or TestFlight deployment.
---

# Visual acceptance

The developer wants to see the feature while the PR is open, not after it merges. Publish screenshots as soon as the first Glass UI job finishes, then refresh them only if the UI changes later.

- **Show:** capture the feature or fix described in the PR from its current code. Add UI-test steps that screenshot the new state if no existing journey reaches it.
- **Limit:** use 1–3 screenshots by default. Skip duplicates and unrelated screens.
- **Video:** only when the change is motion itself (an animation or transition) and screenshots can't show it. Don't record or review video otherwise.
- **Check:** confirm that the screenshots show the requested behavior, publish them with `scripts/pr-visual-evidence.py` and check that they display clearly in the PR.
- **Clean up:** remove temporary downloads after publishing.
- **Device panels:** close task-owned connections as soon as interactive verification finishes, fails or is handed off. State the check and purpose while a connection stays open. Leave a shared simulator running unless shutdown is requested or it was created solely for this task.

For non-UI changes, report the functional checks instead.
