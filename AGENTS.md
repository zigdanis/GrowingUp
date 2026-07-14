# GrowingUp Agent Notes

### Standing Rules

- Always start replies with `Danis, ...`.

## Code Style

- Always strive for concise, simple solutions. Channel "yagni" energy unless told otherwise.
- If a problem can be solved in a simpler way, propose it.
- Dont be scared to propse bold ideas if they can meaningfully benefit our work
- Tests are good! Endless smoke tests, "regression tests" for feature dleetions, etc, much less good. Tests should be focused, not slop.

## General Preferences

- If asked to do too much work at once, stop and state that clearly.
- If `computer use` is helpful for completing or verifying work, use it.

## Picking Models for Workflows and Subagents

Rankings are higher-is-better. Cost reflects what I actually pay, not list price. Intelligence is how hard a problem can be handed to model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model                | cost | intelligence | taste |
|----------------------|-----:|-------------:|------:|
| gpt-5.6-terra-medium |    4 |            6 |     8 |
| gpt-5.6-luna-medium  |    8 |            3 |     3 |
| gpt-5.6-sol-medium   |    1 |            9 |     5 |

Use `sol` for orchestrating work that needs judgment. Use `terra` for normal code changes, tasks that doesnt require much imagination, tasks that doesnt require complext problem-solving. Use `luna` for cheap checks and small edits, for simplest subagents: search, summarize, classify, rewrite, mechanical edits, and first-pass failure triage.

### How to apply:

- These are defaults, not limits. GPT can override them: if a cheaper model's output does not meet the bar, rerun or redo the work with a smarter model. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Bulk/mechanical work with a clear spec goes to `luna` first: search, summarize, classify, rewrite, migrations, data cleanup, simple implementation, and first-pass failure triage.
- Anything user-facing, including UI, copy, and API design, needs taste >= 7. Use `terra` by default.
- Reviews of plans and implementations use `sol`. Optionally run `luna` first for cheap issue discovery.
- Never use expensive models for bulk work unless cheap output fails or judgment is required.

### Mechanics:

- Parallel implementation agents must use isolated worktrees so edits do not collide in the shared checkout.
- Track real worker, purpose, and rough cost when cost matters, especially when multiple subagents are used.