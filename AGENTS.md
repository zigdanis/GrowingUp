## Standing Rules

- Always start replies with `Danis, ...` or `Данис, ...`.

## Code Style

- Always strive for concise, simple solutions. Channel "yagni" energy unless told otherwise.
- Tests are good! Endless smoke tests, "regression tests" for feature dleetions, etc, much less good. Tests should be focused, not slop.
- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.

## Code Review

- Before reviewing changes, read and apply `.macroscope/correctness/correctness.md`. It is the shared review policy for Codex, CodeRabbit, Greptile, and Macroscope.
- Report only concrete, actionable problems introduced by the change. Do not repeat formatter or linter findings, demand speculative abstractions, or invent findings when no shared rule applies.
- When asked to babysit a pull request, use the `babysit-pr` skill when available. Validate each bot finding before changing code, use bounded subagents when useful, run the checks that cover each fix, push only to the pull request branch, and reply with evidence before resolving a review thread.
- After every push, re-check the latest head commit, required checks, new reviews, and unresolved conversations. Continue until the current head is green, reviewers have reached a terminal state, and no actionable thread remains.
- Never merge or enable auto-merge. Hand the clean pull request to Danis for final review.
