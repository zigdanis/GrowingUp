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
- **Device:** everything about the simulator (which pool device, the queue, reaching MacPro from Linux, installing, data left by other threads, the cloud fallback and releasing it afterwards) is in the Fleet `simulator-queue` skill (`~/myai/fleet/skills/simulator-queue/SKILL.md`); follow it. For an interactive check, install the CI build from `scripts/simulator-app.sh [PR_NUMBER]`; the bundle ID is `pro.ziganshin.GrowingUp`. While a Device panel stays open, state the check it is for.
- **Clean up:** release the simulator as the `simulator-queue` skill says, and remove temporary downloads after publishing.

## What a fresh install shows

- The app starts at the empty state with an **Add person** button. The editor's photo control is **Add a photo**, which opens a menu with Camera and Photos.
- Photos first asks for library access: press **Allow Full Access**. The simulator includes sample photos.
- The simulator has no camera, so Camera shows **Camera access needed**.
- An element hidden behind the keyboard can't be tapped; run agent-device's `keyboard enter` first.
- The photo sheet's controls render about 4% smaller than their nominal size: a 44-point glass button measures 42.25 points.

For non-UI changes, report the functional checks instead.
