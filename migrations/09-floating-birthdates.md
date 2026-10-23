# Migration: floating birthdates (`GrowingUpFloatingBirthdates` model)

## What changed

- New Core Data model version `GrowingUpFloatingBirthdates.xcdatamodel`, now the current
  version of `GrowingUp.xcdatamodeld`. It is a copy of `GrowingUpCelebrations` where
  `CoreDataPerson` gains `floatingBirthdate` (optional `Date`) and the old `birthdate`
  becomes optional.
- `floatingBirthdate` holds the date and clock time of birth written as UTC: 10 May 2020
  without a known time is `2020-05-10 00:00:00 +0000`. `Person.birthday` turns it into the
  moment the local clock shows that reading, so every reader (app, widgets, Lock Screen)
  keeps using a local `Date` in `Calendar.current`. The old `birthdate` was the absolute
  moment of local midnight where it was entered, so after flying west a date-only
  birthday read as the previous day in the evening and the editor turned the birth-time
  toggle on (issue #74).

## Why lightweight migration is enough

Adding an optional attribute and making another one optional are inferable changes. The
values themselves cannot be converted by an inferred mapping, so right after loading the
store `CoreDataStackImplementation` pins every person whose `floatingBirthdate` is still
`nil`: it stores the date and time the old `birthdate` shows in the current time zone, the
day the user sees today. This runs inside the cross-process store claim, so the app and
the widget never pin twice, and it is saved in one transaction. If it fails, it is logged,
people read in the current time zone as before, and the next load tries again.

## How to verify

- Unit tests: `CoreDataPersonsGatewayTests` upgrades stores from every earlier model, and
  checks that an upgrade in Moscow pins 10 May (date only) and 29 February 23:50 and that
  both still read the same in New York. `BirthdayTravelTests` enters birthdays in Moscow
  and reads them in New York and Tokyo through the editor and the person page.
- Upgraded install: install the previous TestFlight build and add a person with a date
  only. Install this build, then change the device time zone (Settings › General › Date
  & Time) to one several hours west. The birthday keeps its day, the editor shows no birth
  time, and the age and countdown match the original time zone.
