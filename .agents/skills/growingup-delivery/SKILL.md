---
name: growingup-delivery
description: Deliver GrowingUp fixes from screenshots or text, features, improvements, and new-build requests through implementation agents, independent review, visual feedback, and verified delivery. Use automatically for these action requests in GrowingUp; read-only questions and general discussion do not start delivery.
---

# GrowingUp delivery

Own the requested outcome until it is demonstrated on the current PR head. A code
change or green build alone is insufficient for user-visible work. This is the
repository's delivery workflow; use existing scripts and skills rather than
building another orchestration layer.

## Establish the outcome

1. Inspect the supplied screenshot and relevant code. Turn the text/image into
   observable acceptance criteria, including the interaction that produces the
   result. Treat annotations as the requested change, not app UI. Resolve routine
   choices from the repository; ask only for missing information that affects the
   outcome, while continuing independent work.
2. Inspect the working tree, branch, existing PR, and current checks. Preserve
   unrelated changes and continue an existing task PR where appropriate. Register
   each PR worked on with T3 `link_pull_request` when available, immediately after
   finding/creating it; verify the thread's PR list before handoff.
3. Read applicable repository rules. For bugs, use `diagnosing-bugs` when available.
   Otherwise define an observable failing check, reproduce when the environment
   permits, identify the cause, apply the smallest fix, and rerun relevant checks
   and visual verification. Distinguish observations from unverified hypotheses.
   Use the relevant SwiftUI skills for SwiftUI changes. For UI work, read
   [visual-acceptance](../visual-acceptance/SKILL.md) and
   [remote iOS verification](../../../docs/remote-ios-verification.md) before
   planning validation. If previous-thread context is requested and accessible,
   read its actual handoff/evidence; report unavailable context precisely.

The outcome is defined when each criterion has an observable check and the
implementation/evidence scope is clear. Reproduce the reported behavior when the
available environment permits; distinguish observation from a code-based diagnosis.

## Implement with visual feedback

1. Delegate a bounded implementation to a subagent: provide acceptance criteria,
   relevant files, validation needs, and exclusive file ownership. One implementer
   is sufficient for a small fix; parallelize only independent work. Keep branch,
   commit, push, and PR mutations with the coordinating agent. If delegation is
   unavailable, state that limitation and continue the authorized work.
2. Integrate the implementation and focused tests required by the changed contract.
   For UI behavior, update the relevant XCUI journey with meaningful assertions
   and named checkpoints proving the criteria. Avoid redundant smoke tests or
   tests that merely restate framework behavior.
3. Open the task PR as a draft while acceptance is still being established. Check
   the UI during implementation, after each substantial UI iteration. Prefer T3
   `device_*` tools for live feedback when they expose an authorized device; check
   device availability first. If access is disabled, use the existing validation
   environment rather than enabling devices or changing configuration. On macOS,
   reuse an existing compatible simulator. On Linux/Raspberry Pi, push the task PR
   branch and use its macOS CI plus `scripts/pr-evidence.sh PR_NUMBER`.
   Inspect the relevant exported screenshots and recording segment/frames, compare
   them with every acceptance criterion and the supplied screenshot, and correct
   concrete mismatches on the same PR. This feedback loop precedes final handoff;
   it is not deferred until all code has been declared complete.
4. Use actual current-head evidence for each iteration. Old evidence may explain
   the original failure but cannot validate the fix. Inspect the MP4 when motion
   matters; extracted frames establish states, not animation smoothness. Keep
   reproducible outputs outside the repository and remove them after review.
   Update visual baselines only for inspected, intentional appearance changes
   after functional behavior passes; a failing comparison alone is not grounds
   to accept a new baseline. CI never records baselines.

Finish implementation when the requested behavior passes its relevant checks and
visual inspection. Missing evidence or a partial CI artifact leaves it unverified.

## Independent review and PR convergence

1. Have independent subagents review the actual diff: one checks the request and
   acceptance coverage; another checks concrete correctness against
   [.macroscope/correctness/correctness.md](../../../.macroscope/correctness/correctness.md).
   Give reviewers the request, diff/base/head, and relevant evidence, without
   dictating findings. For UI changes, the acceptance reviewer also independently
   inspects the actual screenshots and relevant clip against each user criterion;
   an implementer cannot independently review its own changes.
   Run reviews in parallel when slots permit, otherwise sequentially. No findings
   is a valid result.
2. Write the PR description around the final problem, behavior, and validation.
   For visible changes, select inspected feature screenshots and a short video
   when interaction/motion needs proof; publish them with
   `scripts/pr-visual-evidence.py` following `visual-acceptance`. Read back the PR
   and verify images render and videos play. Actions artifact download links do
   not replace embedded feature evidence. Explain why screenshots do not apply
   to nonvisual work and report its relevant functional checks. Once implementation,
   required checks, independent review, and current evidence pass, mark a draft
   ready and trigger/await bot reviews. Bots may skip drafts; this transition
   starts external review; delivery continues until the merge gates pass.
3. Validate each local or bot finding before changing code. Fix actionable problems,
   run the checks covering the fixes, and respond with evidence before resolving
   review conversations. Use `babysit-pr` when available for PR monitoring.
4. After every push, reread the current head, required checks, new reviews, and
   unresolved conversations. Recheck any changed criterion and refresh visual
   evidence invalidated by a push or CI rerun. Wait for reviewers to reach a
   terminal state. Repeat only for a new change, failed check, or concrete concern.

Finish PR convergence when the latest head has green required checks, independent
and bot reviews have no remaining actionable findings, review conversations are
accounted for, and the PR contains current inspected feature evidence where applicable.
Then follow the authoritative [merge and approval policy](../../../AGENTS.md#merge-and-approval-policy).

Report the PR, head/CI, criteria demonstrated, and material limits concisely. If
tools, CI, review, uploads, or device-only coverage block the result, name the exact
missing condition and the next action. A real blocker is not successful completion;
continue every independent authorized part before yielding for required input.

## New build and TestFlight

A request for a new build activates this workflow, including preparing a reviewable
change and build verification. Publishing to TestFlight requires current inspected
PR evidence and Danis's explicit deployment instruction under
[docs/testflight.md](../../../docs/testflight.md). An ordinary fix/feature request,
green CI, or PR approval alone does not authorize release. Honor explicit deployment
authorization already given in the session. Present evidence for new UI work and
satisfy the release gates without asking again for the same authorized deployment.

For a deployment-only request, inspect the selected existing change and its evidence
instead of manufacturing another code change or implementation task. Follow
`docs/testflight.md` for source/CI checks, EN/RU notes, dispatch, receipts, and recovery.
Follow [AGENTS.md](../../../AGENTS.md#merge-and-approval-policy) to merge the verified
change, then release only its permitted reviewed master source after that source's
CI passes. Monitor the same recorded release and report the actual version/build
and Apple state. Distinguish workflow success, Apple availability, and delivery
on Danis's device; keep any required device confirmation pending instead of
uploading another build.
