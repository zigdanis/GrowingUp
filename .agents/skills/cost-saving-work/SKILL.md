---
name: cost-saving-work
description: Route suitable bounded work through cheaper GPT models. Use when the user says "save me tokens", "make it cost efficient", "use cheaper models", "optimize model cost", "delegate this cheaply", "orchestrate cost-effectively", "manage effective model usage", or explicitly invokes $cost-saving-work.
---

# Cost-Saving Work

Reduce cost without surrendering orchestration or verification.

## Decide whether to delegate

Delegate searches, building and running projects on simulator, navigating through app on simulator, collecting logs from simulator, deploying to Testflight, summaries, classification, audits, mechanical transformations, first-pass triage, and other bounded work. Keep tiny tasks local when delegation overhead would cost more. Keep user-facing design, high-risk judgment, and final verification with orchestrator unless user directs otherwise.

## Select worker

Use cheapest model likely to meet task bar. Default simple worker to `gpt-luna-medium`. Escalate when output is weak, uncertain, or incomplete.

Tell user which real worker and model will run. Workers must not spawn agents, change models, make orchestration decisions, or expand task scope.

## How to handle models interaction

Use cheap model to run, navigate and collect logs when using iOS simulator. Pass collected results to more intelligent model to make decisions based on findings from the cheap model work.
