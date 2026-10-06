# Six-person widget release notes

Prepared notes: [widget-six-people.json](widget-six-people.json).

Previous processed upload: TestFlight 2.1.6 (28), receipt
`testflight/receipts/37415330031`, source
`f0093992ed5a15a6afb7217d9ed2a685e1daf19d`. Apple receipt reports
`VALID` processing and verified EN/RU notes; its recorded external review state
is `WAITING_FOR_BETA_REVIEW`, so availability on Danis’s device is unconfirmed.

This task starts from that exact source. Its user-facing diff adds a large
Home Screen widget with two rows of three, increases pin capacity to six,
retains small/medium capacity at one/three, and updates the localized limit
message. The previous database model remains bundled so Core Data can open
and upgrade existing stores without losing people or photo references.

Before dispatch, compare the final reviewed master SHA against this source,
check receipts for intervening shipped builds, and adjust these notes only
for actual additional user-facing changes. The workflow chooses the next
version/build; this filename does not reserve either.

Authorization: Danis requested this feature through a new TestFlight build
in this thread. Present inspected current-head PR evidence first. Deployment
requires Danis to merge the reviewed PR; agents cannot merge or enable auto-merge.
