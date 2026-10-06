---
name: visual-acceptance
description: Capture, inspect, and attach feature-specific iOS simulator screenshots or videos to GrowingUp PR descriptions. Use for user-visible feature work and UI fixes, including work from Linux or Raspberry Pi, before merging a PR or deploying to TestFlight.
---

# Visual acceptance

Make the requested behavior quick for Danis to assess in the PR description.
Use the existing macOS CI/XCUI evidence pipeline; read
[docs/remote-ios-verification.md](../../../docs/remote-ios-verification.md)
for retrieval, inspection, publication commands, and simulator limits.

1. Translate the request into observable acceptance criteria. Extend the relevant
   `GrowingUpUI` journey with assertions and named screenshot checkpoints that
   show the feature's actual result, using deterministic test fixtures. Choose a
   screenshot when a final state proves the criterion; choose a short recording
   when navigation, gestures, persistence across relaunch, or animation matters.
   Include relevant language/appearance variants when the change affects them.
2. Push the PR branch and retrieve evidence for its current head. Inspect the
   selected screenshots and the relevant recording segment against every
   criterion. Fix concrete failures and repeat on the same PR. Green CI, old
   baselines, mockups, and unrelated journeys do not establish acceptance.
3. Select the smallest useful demonstration from the passing run. Trim a recording
   to the feature's interaction and outcome. Preserve real timing when judging
   animation. Describe what you inspected, its outcome, and any device-only gaps
   in a temporary Markdown summary. Publish through `scripts/pr-visual-evidence.py`;
   it embeds native GitHub images/video in the PR body and preserves other sections.
4. Read back the PR description and confirm the media renders. After a new push or
   CI rerun, replace evidence with reviewed media for the latest head/attempt before
   handoff. Media upload failures leave the description untouched; inspect a failed
   PR-update request before retrying. Remove
   temporary downloads and clips after publication and review.

Finish when the PR body contains current, inspected evidence covering the requested
behavior, with its commit/run and honest limitations. For a feature without a
visible app effect, explain that in the PR and report its functional verification;
do not attach an unrelated app screenshot. If CI, uploads, or device coverage block
acceptance, state the concrete gap and keep the work unverified.

Visual acceptance completes the evidence gate. Follow the authoritative
[merge and approval policy](../../../AGENTS.md#merge-and-approval-policy) and
[TestFlight workflow](../../../docs/testflight.md). Publish inspected evidence
before deployment; honor an explicit deployment instruction already given in
the session without asking again for the same authorized release.
