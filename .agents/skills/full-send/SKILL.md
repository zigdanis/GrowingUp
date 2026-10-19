---
name: full-send
description: Deliver features, fixes and new builds through implementation, review, checks and merge. An explicit full-send request includes TestFlight. Discussion and read-only questions do not start delivery.
---

# Full send

A PR should open within the hour, show screenshots while it's still open, and merge the same day. Any loop that repeats without new information is a bug in the process: stop and report it.

## Roles

- **Lead:** one agent (Sonnet 5.5, high) runs the workflow and owns Git, the PR, merging and release.
- **Implementer:** Opus 5.5 for features, Sonnet 5.5 for small fixes. Implements only the assigned task and doesn't delegate further.
- **Reviewer:** one independent Codex GPT-6.1-Sol review before the first push. Use Fable 5.1 only for design questions or a bug nobody can explain.
- **Fallback:** if delegation is unavailable, the lead implements and still gets the Codex review.

## Authorization

- **Full-send:** when the developer explicitly requests it, finish through PR, merge and TestFlight. Don't ask for deployment permission again.
- **TestFlight:** an explicit TestFlight request also authorizes beta deployment. App Store actions need separate approval.
- **Limits:** `PR-only` stops before merge. `No-deploy` stops before TestFlight.
- **Discussion:** loading or discussing this skill does not authorize a release.

## Flow

1. **Understand:** know the requested change and what success looks like. Reuse an existing PR for the same task. For UI changes, also use `visual-acceptance`.
2. **Implement:** make the change with focused tests, then run the Linux checks: `python3 -m unittest discover -s scripts/tests` and `scripts/check-secrets.sh`.
3. **Review once:** have the Codex reviewer check correctness and the requested behavior. Fix confirmed issues before pushing.
4. **Open the PR early:** push and open the PR, as a draft if work remains. Write the description for the developer (see below). One push per batch of fixes.
5. **Show:** once the Glass UI job finishes, publish 1–3 screenshots with `scripts/pr-visual-evidence.py` while the PR is open.
6. **Bot comments:** handle the bots' first review in one batch (see the [verification policy](references/verification-policy.md)). Don't ask for another bot review.
7. **Merge:** merge when the merge gate passes. A behind-master branch doesn't need an update unless it conflicts.
8. **Release:** follow the steps below when authorized.

## PR description

- **First line:** `Status: <what we're waiting on, or "ready to merge">`. Update it at every step so the developer never has to guess.
- **Body:** under 200 words: what changed for the user, screenshots, how to try it, and anything still unverified. Keep the history of review rounds and CI attempts in the thread, not in the PR.

## Release and report

- **Reuse:** for a release-only request, use existing verified code instead of inventing changes.
- **Ready:** run `python3 scripts/testflight.py ready` to check setup. Use cloud `preflight` only for setup or diagnosis; deployment already checks signing.
- **Notes:** save plain-text English/Russian JSON with `en` and `ru` in `docs/releases/`, based on actual user-facing changes since the last shipped source. Separate new changes from testing instructions; omit emoji and `<`.
- **Release:** when authorized, use `python3 scripts/testflight.py deploy next MASTER_SHA NOTES_JSON` for the merged commit after its master CI passes. Keep the run ID, receipt and version/build.
- **Resume:** use the same tool's `status RUN_ID` or `resume RUN_ID` for an interrupted release, never a duplicate upload. Use `notes RUN_ID NOTES_JSON` for text-only corrections without rebuilding.
- **Wait:** if Apple processing, beta review or phone confirmation is pending, report what's missing.
- **Report:** share the PR, version/build, CI attempts and actual release status. For first delivery, ask the developer to confirm the build and notes on their phone before claiming completion.
