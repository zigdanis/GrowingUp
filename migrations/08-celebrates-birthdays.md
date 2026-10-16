# Migration: per-person birthday celebrations (`GrowingUpCelebrations` model)

## What changed

- New Core Data model version `GrowingUpCelebrations.xcdatamodel`, now the current
  version of `GrowingUp.xcdatamodeld`. It is a copy of `GrowingUpSixPeople` with one
  new attribute on `CoreDataPerson`:
  `celebratesBirthdays` — non-optional `Boolean`, scalar, default `YES`.
- `Person`, `AddPersonParameters` and `CoreDataPerson` carry the flag. The editor's
  "Celebrate birthdays" chip edits it, and the overview only starts the birthday
  confetti when it is on. The birthday indicator and countdown are unaffected.

## Why lightweight migration is enough

Adding a non-optional attribute with a default value is an inferable change, so no
mapping model is needed. Both persistent stores (`CoreDataStackImplementation` for the
app and widget, `UITestStore` for journeys) keep `NSPersistentStoreDescription`'s
defaults, `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically`
(both `true`). On first launch after the update Core Data migrates the App Group store
in place and every existing person gets `celebratesBirthdays = YES`, so behaviour is
unchanged until someone turns the chip off. The app and widget share the same model,
so whichever process opens the store first performs the migration.

## How to verify

- Unit tests: `CoreDataPersonsGatewayTests` migrates stores created with the original
  `GrowingUp` model and with `GrowingUpSixPeople` to the current model and checks that
  people, pins and photo identifiers survive and that celebrations default to on. The
  round-trip test checks add/edit/fetch of the flag.
- Upgraded install: install the previous TestFlight build, add people (some pinned,
  with photos), then install this build over it. All people, photos and widget pins
  must still be there, each editor shows "Celebrate birthdays" selected, and a person
  whose birthday is today still gets confetti. Turn the chip off, save, relaunch: the
  choice persists and the confetti no longer plays, while the birthday indicator stays.
