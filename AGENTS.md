## Standing Rules

- Always start replies with `Danis, ...` or `Данис, ...`.
- For GrowingUp fixes from screenshots or text, feature work, improvements, and requests for a new build, always read and apply [growingup-delivery](.agents/skills/growingup-delivery/SKILL.md). It owns the workflow through implementation, independent review, visual feedback, and verified delivery; TestFlight follows its deployment authorization gate. General discussion and read-only questions do not trigger delivery.
- Never place DerivedData, `.xcresult` bundles, downloaded CI artifacts, or other reproducible validation output inside the repository. Use Xcode's default DerivedData location or a `mktemp` directory, and remove temporary validation artifacts when the run is complete.
- Reuse an existing compatible simulator for local builds and tests. Never create a local simulator unless Danis explicitly asks for one; if temporary simulator creation is explicitly approved, delete it as soon as the run completes.
- On Linux, validate iOS changes through the PR's macOS CI and `scripts/pr-evidence.sh PR_NUMBER`. Follow `docs/remote-ios-verification.md`: inspect relevant exported screenshots and recording frames for the latest head, fix concrete failures on the same PR, and remove downloaded evidence after review. A green build alone does not verify UI behavior.
- Every screenshot in any PR description must follow the [compact media rules](docs/remote-ios-verification.md#compact-pr-media) for sizing, layout and rendered inspection. Publish reviewed CI screenshots through `scripts/pr-visual-evidence.py`.
- For user-visible features and UI fixes, use `.agents/skills/visual-acceptance/SKILL.md` before merging a PR or deploying to TestFlight. Attach inspected screenshots or a short feature demo to the PR description for the current head. Deploy to TestFlight only after Danis explicitly approves deployment.

## Code Style

- Always strive for concise, simple solutions. Channel "yagni" energy unless told otherwise.
- Tests are good! Endless smoke tests, "regression tests" for feature dleetions, etc, much less good. Tests should be focused, not slop.
- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Declare only one type per Swift file; direct extensions of that file's primary type are the only exception.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.

## Code Review

- Before reviewing changes, read and apply `.macroscope/correctness/correctness.md`. It is the shared review policy for Codex, CodeRabbit, and Macroscope.
- Report only concrete, actionable problems introduced by the change. Do not repeat formatter or linter findings, demand speculative abstractions, or invent findings when no shared rule applies.
- When asked to babysit a pull request, use the `babysit-pr` skill when available. Validate each bot finding before changing code, use bounded subagents when useful, run the checks that cover each fix, push only to the pull request branch, and reply with evidence before resolving a review thread.
- After every push, re-check the latest head commit, required checks, new reviews, and unresolved conversations. Continue until the current head is green, reviewers have reached a terminal state, and no actionable thread remains.

## Merge and approval policy

- Merge or enable auto-merge autonomously once the latest PR head has green required checks, completed independent and bot reviews with no actionable findings or unresolved conversations, and current inspected visual evidence where applicable. Recheck the head and these gates immediately before merging; verify the resulting master commit and its CI before deployment.
- Ask for approval only for a concrete one-way-door action: an irreversible or hard-to-reverse change, or one that could cause substantial losses. State the exact consequence that requires the decision and complete the independent, reviewable preparation first. Routine reversible changes and TestFlight beta updates do not require another confirmation.
- TestFlight still requires an explicit deployment instruction and the source, CI, and evidence gates in [docs/testflight.md](docs/testflight.md). Honor authorization already given in the session; continue through merge and deployment without asking again for the same approved work.
