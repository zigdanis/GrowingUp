# Discussion: Concurrency direction — keep GCD `TaskManager` or move to async/await?

> **This is a discussion / decision doc, not an implementation ticket.**
> Nothing is implemented until a direction is chosen below. The PR thread is the
> place to debate it.

## Current state

GrowingUp does background work through a small hand-rolled abstraction:

```swift
public typealias Task = () throws -> Void

public protocol TaskManager {
    func process(tasks: [Task])
}

public final class TaskManagerOnGCD: TaskManager {
    public func process(tasks: [Task]) {
        let queue = DispatchQueue.global(qos: .utility)
        let group = DispatchGroup()
        for task in tasks {
            let workItem = DispatchWorkItem { try? task() }
            queue.async(group: group, execute: workItem)
        }
    }
}
```

- Injected into gateways (e.g. `CachePersonsGateway`) via the `Configurator`s.
- Has a test spy (`TaskManagerSpy`).
- Note the current implementation **swallows thrown errors** (`try? task()`),
  fires-and-forgets (the `DispatchGroup` is created but never `notify`/`wait`ed),
  and the typealias name `Task` now collides with Swift's `_Concurrency.Task`.

## Options

### Option A — Keep `TaskManager` (GCD), but fix it
- Smallest change; preserves the protocol seam used by tests/DI.
- Fix the real bugs: propagate/handle errors, actually use `DispatchGroup.notify`
  for a completion callback, rename `Task` to avoid the stdlib clash.
- **Cons:** stays on a manual concurrency model; no structured concurrency,
  cancellation, or `await` ergonomics.

### Option B — Migrate to Swift Concurrency (async/await)
- Replace `TaskManager`/`process(tasks:)` with `async` gateway methods and
  `async let` / `withThrowingTaskGroup` at call sites.
- Use actors where shared mutable state needs isolation (e.g. caches); make
  Core Data access async-friendly.
- **Pros:** structured concurrency, real error propagation, cancellation,
  testability without a custom spy, removes the `Task` name clash.
- **Cons:** larger diff; touches gateways, use cases, presenters/view models;
  interacts with the SwiftUI and deployment-target tickets.

### Option C — Hybrid / incremental
- Introduce async/await at new/seam boundaries while keeping `TaskManager`
  behind an async adapter, migrating call sites gradually.

## Recommendation (for debate)

Lean **Option B (async/await)** *because* the project is already raising its
deployment target (see the iOS 18 ticket) and migrating the UI to SwiftUI —
both of which pair naturally with async/await — and because the current GCD
implementation is quietly buggy (swallowed errors, unused group). The
`TaskManager` protocol seam can be preserved initially (Option C) to keep the
diff reviewable, then retired.

> The maintainer's stated preference is **not** to keep DispatchGroup in
> preference to async/await. This doc exists to confirm scope/sequencing before
> committing.

## Decision

- [ ] **A** — keep & fix GCD `TaskManager`
- [ ] **B** — migrate to async/await
- [ ] **C** — hybrid/incremental, then retire `TaskManager`

Once a box is checked, a follow-up implementation ticket (same format as the
other `migrations/*.md` prompts) will be authored for the chosen path.
