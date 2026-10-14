---
name: full-send
description: Deliver features, fixes and new builds through implementation, review, checks and merge. An explicit full-send request includes TestFlight. Discussion and read-only questions do not start delivery.
---

# Full send

- **Lead:** one agent runs the workflow and handles Git, PR and release actions.
- **Helpers:** use one implementer and one independent reviewer by default. They handle only their assigned tasks and do not delegate further.

## Authorization and ownership

- **Full-send:** when the developer explicitly requests it, finish the task through PR, merge and TestFlight after checks and reviews pass. Don’t ask for deployment permission again.
- **TestFlight:** an explicit TestFlight request also authorizes beta deployment. App Store actions need separate approval.
- **Limits:** `PR-only` stops before merge. `No-deploy` stops before TestFlight.
- **Discussion:** loading or discussing this skill does not authorize a release.
- **Verification:** read the [verification policy](references/verification-policy.md) once at the start. Follow its batching, failure-handling and waiting rules throughout.

## Understand the task

- **Understand:** identify the requested change and what a successful result looks like.
- **Continue:** reuse existing task work and its PR when possible. Leave unrelated changes alone.
- **UI:** use `visual-acceptance` for UI changes.

## Implement and review

- **Assign:** give the implementer a focused task, expected result and file ownership. If delegation is unavailable, implement it yourself.
- **Implement:** make the requested change, add appropriate tests and run local checks.
- **Review:** have an independent reviewer check correctness and the requested behavior. Fix confirmed issues before pushing.
- **Sync and push:** batch reviewed fixes, fetch the latest base branch and integrate it before pushing. Run relevant local checks on the combined result, then recheck the remote base immediately before one push. Create or update the PR and use automatic CI instead of launching a duplicate.

## Verify and merge

- **Verify:** check that tests pass and the feature works; inspect the UI with a reviewer.
- **Show:** attach current screenshots or a demo to the PR. Non-UI changes don’t need screenshots.
- **Fix:** address real review issues, test the fixes and reply before resolving comments.
- **Watch:** for pending PR checks or reviews, call T3 Code's `watch_pull_request` and end the turn. Recheck when notified; use `unwatch_pull_request` when handing back to the developer.
- **Merge:** wait for checks and reviews to pass. Before TestFlight, verify CI on the merged code.

## Release and report

- **Reuse:** for a release-only request, use existing verified code instead of inventing changes.
- **Ready:** run `python3 scripts/testflight.py ready` to check setup. Use cloud `preflight` only for setup or diagnosis; deployment already checks signing.
- **Notes:** save plain-text English/Russian JSON with `en` and `ru` in `docs/releases/`, based on actual user-facing changes since the last shipped source. Separate new changes from testing instructions; omit emoji and `<`.
- **Release:** when authorized, use `python3 scripts/testflight.py deploy next MASTER_SHA NOTES_JSON` for the verified merged commit. Keep the run ID, receipt and version/build.
- **Resume:** use the same tool's `status RUN_ID` or `resume RUN_ID` for an interrupted release, never a duplicate upload. Use `notes RUN_ID NOTES_JSON` for text-only corrections without rebuilding.
- **Wait:** if Apple processing, beta review or phone confirmation is pending, report what’s missing and wait for new information under the verification policy.
- **Report:** share the PR, version/build, checks, CI attempts and actual release status. For first delivery, ask the developer to confirm the build and notes on their phone before claiming completion.
