# Remote iOS verification

Agents on Linux use GitHub Actions' macOS runners to build and exercise GrowingUp.
No local Mac, signing credentials, extra cloud service or model API key is needed
for simulator validation. CI runs automatically for pull requests and pushes to
`master`; `gh workflow run ci.yml --ref BRANCH` requests an additional run.

The existing `GrowingUp` scheme covers unit tests. `GrowingUpUI` covers adding,
relaunching, photo selection/cropping/persistence, cancel/save-error recovery,
pin limits/widget deep links, deletion, and English/Russian light/dark appearance.
Glass comparisons remain pinned to iOS 26.5 / iPhone 17 Pro / arm64. iOS 18.5 /
iPhone 16 checks behavior without comparing Glass baselines. Missing baselines
fail; CI never records new baselines.

## Review a pull request from Linux

Push the PR branch, then run from the repository with authenticated `gh` and `jq`:

```bash
scripts/pr-evidence.sh PR_NUMBER
```

The command finds CI for the current PR head, waits for completion and downloads
`ui-*` artifacts into a new temporary directory outside the repository. It checks
the artifact's source commit/run and rechecks the PR head after waiting and after
downloading. It exits nonzero when CI fails, while retaining available evidence
for diagnosis. A missing run/artifact is an error, not a successful validation.
Documentation-only PRs skip simulator jobs and have no UI evidence to download.

Each simulator artifact contains:

- `index.html`: an offline report with test results, images and a video player.
- `journeys.mp4`: the UI suite, recorded after compilation; stopped cleanly even
  when assertions fail. It includes simulator launch/relaunch transitions.
- `attachments/`: exported screenshots and expected/actual/difference images on
  visual failures, plus `manifest.json` mapping images to their test journeys.
- `test-summary.json` and `tests.json`: machine-readable results exported on macOS.
- `metadata.json`: PR head SHA, checked-out SHA (the PR merge commit on PR runs),
  run ID/attempt, Xcode, simulator, visual-check mode and step outcomes.
- `build.log`, `xcodebuild.log`, `recording.log` and `UI.xcresult`: raw diagnostics.

Early build or simulator failures can produce a partial artifact. Inspect its
metadata and Actions logs; absence of screenshots/video does not establish that
the app works. Download links also appear in the Actions job summary. Artifacts
expire after 14 days. Keep the extracted directory together when opening
`index.html`; GitHub downloads the report rather than hosting it as a website.

## Agent iteration

1. Add or update the relevant XCUI journey for the requested behavior, push the
   same PR branch and retrieve evidence for that commit.
2. Read CI results and `test-summary.json`. Inspect the named checkpoint images
   and visual differences with the agent's image viewer.
3. Review the video for interaction/animation issues. For an image-based viewer,
   extract frames on Linux outside the repository:

   ```bash
   ffmpeg -i /tmp/EVIDENCE/journeys.mp4 -vf fps=1/2 /tmp/EVIDENCE/frame-%04d.png
   ```

   Inspect frames around the relevant journey; a contact sheet can help locate
   it. Still frames do not establish animation smoothness; view the MP4 when that
   matters. Exported checkpoint images are the source for exact comparisons.
4. Validate failures against the requested behavior, fix concrete issues and
   repeat on the same PR. Recheck all required checks and review conversations
   after each push. Report the run URL, reviewed checkpoints and remaining limits.
5. Remove downloaded artifacts and extracted frames after review. Leave merging
   to Danis.

This makes evidence available to the agent already working on the PR. Visual
inspection is part of that agent's work; CI does not make an additional model call
or treat a green test suite as proof of all UI behavior. Camera hardware, actual
Home Screen widget hosting and device-only rendering still need device coverage;
the current widget journey verifies the app's deep link and pin rules.

TestFlight distribution is a separate release operation using the existing
fastlane lanes. Simulator evidence does not upload or distribute a build.

## Maintain the evidence tools

```bash
bash -n scripts/run-ui-journeys.sh scripts/pr-evidence.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests
```

The focused tests exercise recorder finalization, failed-test status preservation,
build failures and portable report generation. Real simulator behavior is verified
by both macOS UI jobs.
