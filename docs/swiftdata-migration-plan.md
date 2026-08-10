# Core Data to SwiftData Migration Plan

## Status and scope

This document proposes a future, implementation-only migration of GrowingUp's persistence layer from Core Data to SwiftData. The migration itself is intentionally **not** part of this change.

In scope:

- persisted people and their widget visibility;
- the shared App Group store used by the app and WidgetKit extension;
- the persistence gateway, composition roots, error mapping, and persistence tests;
- preservation of existing user data and image identifiers.

Out of scope:

- changing the `Person`, `AddPersonParameters`, use-case, or presenter APIs unless implementation proves it necessary;
- moving image files out of Disk or changing their format;
- UI changes, CloudKit synchronization, or a general concurrency rewrite.

## Current state

The `Core` framework owns an `NSPersistentContainer` whose SQLite store is at `Application Support/GrowingUp.sqlite` in the `group.pro.ziganshin.aging` App Group. Both the app and widget construct `CoreDataPersonsGateway` and access that store.

The Core Data schema contains:

| Entity | Stored data |
| --- | --- |
| `CoreDataPerson` | optional string `id`, name, birth date, optional app/widget image ID strings, creation date, and an optional relationship to `AccessToWidget` |
| `AccessToWidget` | a to-many relationship containing at most three widget people |

The clean-architecture boundary is already useful: callers depend on `PersonsGateway`, while Core Data types are confined mostly to `Core/EntityGateway/LocalPersistance`. The migration should preserve this boundary and replace the implementation behind it.

Important current behaviors to preserve:

- people are returned in ascending `createdDate` order;
- IDs and image IDs round-trip without changing, because image files are addressed by those IDs;
- widget membership is limited to three people and is visible to both processes;
- gateway completions are delivered on the main thread;
- add, edit, remove, fetch-all, and fetch-widget operations retain their current error semantics.

## Proposed target design

Introduce a SwiftData `@Model` dedicated to persistence and continue mapping it to the domain `Person`. Do not make `Person` a SwiftData model: keeping the domain entity persistence-agnostic preserves the existing architecture and keeps tests/UI independent of framework lifecycle rules.

The persisted person model should initially mirror the values already stored. Represent widget membership directly on the person (for example, as `isOnWidget`) unless migration prototyping finds a compatibility reason to retain a separate singleton model. A Boolean better matches the domain, removes the artificial `AccessToWidget` entity, and makes widget queries explicit. Enforce the maximum of three in the gateway/domain workflow; SwiftData schema declarations do not replace that business rule.

Create one shared `ModelContainer`, configured with an explicit App Group URL, and expose it to both targets through `Core`. Add a `SwiftDataPersonsGateway` conforming to the existing `PersonsGateway`. Use isolated `ModelContext` instances for operations and translate framework errors into `CoreError`. The app and widget must use the same schema version and store configuration in every release.

## Data migration strategy

Do **not** point the first SwiftData container at the existing `GrowingUp.sqlite` and assume it will open safely. Although SwiftData uses Core Data internally, compatibility between the hand-authored `.xcdatamodeld` and a generated SwiftData schema must be proven with a copy of a production-shaped store. The initial implementation should use a side-by-side SwiftData store and an explicit, resumable import.

Recommended flow:

1. Keep the existing Core Data model and reader available for one transition release.
2. Create the SwiftData store under a distinct App Group filename, such as `GrowingUp-SwiftData.store`.
3. On app launch, coordinate migration so only the containing app performs it; the widget should read the last known usable store and request a reload later rather than start migration.
4. Read all Core Data people, validate required values, and transform each record into the SwiftData model. Preserve valid person IDs, image IDs, birth dates, creation dates, and widget membership exactly.
5. Handle malformed legacy values deterministically. Record diagnostics; do not silently generate a new person ID when that could orphan image files. Define and test whether a malformed record is skipped or blocks cutover before implementation ships.
6. Insert/upsert by stable person ID in a transaction-like batch. Write a migration-state marker containing at least the migration version, completion state, record count, and a source-store fingerprint or timestamp.
7. Re-open and verify the destination independently: compare counts and stable IDs, validate mapped values, confirm no more than three widget people, and fetch through the new gateway.
8. Only after successful verification, atomically mark SwiftData as the active backend and reload widget timelines. If import or verification fails, continue using Core Data and leave the source store untouched.
9. Make retries idempotent. A crash at any point must allow the next launch to resume or safely rebuild the incomplete destination without duplicating records.
10. Retain the legacy store for at least one stable release (or a defined support window) to permit rollback. Remove it only after rollout telemetry and support confidence meet the agreed exit criteria.

Before implementation, build a throwaway compatibility spike against copied fixtures to determine whether SwiftData can directly open the old schema without mutation. Direct attachment may reduce migration code, but should replace the explicit importer only if tests demonstrate schema mapping, relationship behavior, rollback, and cross-process access on all supported OS versions.

## Implementation phases

### 1. Discovery and fixtures

- Inventory real schema/store metadata, SQLite sidecar files, App Group entitlements, and all construction sites in the app and widget.
- Create sanitized fixture stores for empty, typical, three-widget-person, malformed-optional-value, and larger datasets.
- Record current gateway contract tests as the behavioral baseline.
- Decide the malformed-record policy and the legacy-store retention window.

Exit criterion: fixtures can be opened by the legacy stack and expected `Person` values are documented.

### 2. SwiftData schema and container

- Add a versioned SwiftData schema and migration-plan type from the first release, even if version 1 has no SwiftData-to-SwiftData migration yet.
- Configure the destination URL explicitly inside the App Group; never rely on SwiftData's default application container.
- Model uniqueness deliberately. Treat person ID as the stable import/upsert key and preserve optional image IDs.
- Validate multi-process access patterns for the app and widget, including store loading while the other process has recently written.

Exit criterion: an empty shared store can be created and read by both targets without changing production wiring.

### 3. Gateway parity

- Implement the SwiftData gateway behind `PersonsGateway` and keep domain mapping at the persistence boundary.
- Match sort order, completion-queue behavior, widget filtering, limit enforcement, and `CoreError` mapping.
- Introduce a small backend-selection abstraction/feature flag so Core Data remains the default during development and rollback remains possible during rollout.
- Update app, edit/add, list, and widget composition roots only after parity tests pass.

Exit criterion: the same contract suite passes against Core Data and SwiftData implementations.

### 4. Explicit importer and cutover

- Implement the migration coordinator and durable state machine (`notStarted`, `importing`, `verifying`, `complete`, `failed`).
- Prevent simultaneous migration by the app and widget. Account for process termination and store sidecars when coordinating or rebuilding.
- Import and verify fixtures, then exercise interruption after each state transition.
- Keep Core Data read/fallback support and never delete the source automatically in the first migration release.

Exit criterion: every fixture migrates idempotently, failure leaves legacy data usable, and successful cutover produces equivalent gateway results.

### 5. Rollout and observability

- Ship behind a staged rollout or remotely/local-configurable kill switch if the app's release infrastructure permits it.
- Log privacy-safe migration duration, source/destination counts, state, failure category, and fallback activation. Do not log names, dates of birth, or IDs.
- Verify add/edit/delete in the app and timeline reads in the widget after cutover, including upgrades where the widget runs before the app.
- Document support recovery steps and the conditions for switching users back to Core Data.

Exit criterion: the defined rollout window completes without unexplained data loss, repeated migrations, or widget regressions.

### 6. Cleanup in a later release

- Remove Core Data gateway wiring, stack utilities, managed-object classes, model resources, legacy test doubles, and importer/fallback code only after the retention window.
- Update persistence documentation and rename Core Data-specific tests.
- Delete the legacy store only through a separately reviewed cleanup path that handles `.sqlite`, `-wal`, and `-shm` files and only after verified backup/retention requirements are satisfied.

Exit criterion: no production or test target links Core Data solely for the retired implementation, and supported upgrade paths no longer require it.

## Verification plan

### Automated tests

- Run a shared `PersonsGateway` contract suite for add, fetch, edit, remove, ordering, missing records, widget membership, and the three-person limit.
- Test domain/model conversion, including missing optional strings and exact UUID/image-ID preservation.
- Test migration from every fixture, repeated migration, partial destination data, cancellation/crash recovery, validation failure, and insufficient disk space where practical.
- Test schema-version upgrades so the next SwiftData model change has a proven path.
- Add integration tests that point both app-like and widget-like containers at the same temporary store and verify changes become visible after context refresh/reload.

### Manual and release checks

- Upgrade an installed pre-migration build containing people and images; compare list order, details, photos, and widget membership before and after.
- Launch the widget before opening the upgraded app, during migration, and immediately after app writes.
- Test clean install, empty store, three widget people, background termination during import, low-storage failure, device reboot, and app reinstall/update behavior.
- Confirm widget timelines are explicitly reloaded after successful mutations and cutover.
- Confirm rollback reads the untouched legacy store and does not incorporate post-cutover writes unless dual-writing has been deliberately designed and tested.

## Rollback approach

The safest initial rollback is **fallback before cutover**: Core Data remains authoritative until import verification succeeds. After cutover, automatic fallback risks losing writes made only to SwiftData. Choose one of these release policies before implementation:

- **Preferred:** once a user writes to SwiftData, do not silently revert; use a kill switch only to stop new migrations and provide a targeted recovery path for migrated users.
- **Higher complexity:** temporarily dual-write after cutover so rollback remains lossless. This expands consistency and failure-handling requirements and should be adopted only if product risk justifies it.

In either case, preserve the Core Data store during the retention window and make backend/migration state explicit and inspectable.

## Pros and cons

### Pros

- Swift-native model declarations reduce managed-object boilerplate and eliminate the separate model-editor file for future schema work.
- Typed fetch descriptors and predicates improve refactor safety compared with string keys and `#keyPath` usage.
- A model aligned with the domain can remove the `AccessToWidget` singleton workaround and make persistence intent clearer.
- Versioned SwiftData schemas establish an explicit foundation for future migrations.
- The persistence gateway boundary allows adoption without coupling presenters, use cases, or UIKit/SwiftUI views to SwiftData.
- The project already targets iOS 18+, avoiding the deployment-target increase that blocks SwiftData adoption in older apps.

### Cons and risks

- The migration adds substantial one-time complexity for a small schema; Core Data is mature and the current gateway already works.
- SwiftData still relies on Core Data internals, so this is an API/modeling simplification rather than a fundamentally different storage engine.
- Existing-store compatibility is not guaranteed merely because both technologies use SQLite/Core Data internals; an unsafe direct-open attempt could corrupt or discard user data.
- App/widget multi-process access, migration ordering, context refresh, and timeline reload behavior require careful device-level testing.
- SwiftData types have framework isolation and lifecycle constraints; leaking them into the domain would make architecture and unit tests worse.
- Rollback becomes difficult after SwiftData accepts new writes unless dual-write or a forward recovery path exists.
- Keeping two stacks for a transition release increases binary size, maintenance, test matrix, and operational complexity.
- Framework behavior varies by OS release, so supported-version regression tests remain necessary even with an iOS 18 minimum.

## Decisions required before implementation

1. Confirm whether the release will use explicit side-by-side import or a proven direct-store compatibility path.
2. Choose the malformed-record policy, especially for invalid/missing person IDs tied to image filenames.
3. Choose post-cutover rollback policy: no silent rollback after writes, or temporary dual-write.
4. Define the legacy-store retention period and rollout success thresholds.
5. Decide whether migration telemetry/kill-switch infrastructure is available and acceptable.
6. Confirm the desired concurrency surface: preserve callback-based `PersonsGateway` initially (lowest scope) or introduce async/await as a separate change.

## Definition of done for the future migration

- All existing valid people, dates, IDs, image references, creation order, and widget selections survive an upgrade.
- The app and widget read the same SwiftData store from the App Group and behave correctly regardless of launch order.
- Gateway contract, migration, interruption, schema-upgrade, and shared-store integration tests pass.
- Migration is idempotent, observable without exposing personal data, and does not delete or mutate the legacy store before verified cutover.
- A documented rollout, rollback, and support-recovery procedure has been exercised.
- Core Data is removed only in a later release after the retention and rollout exit criteria are met.
