# Full-screen acceptance release notes

Prepared notes: [full-screen-acceptance.json](full-screen-acceptance.json).

Previous processed upload: TestFlight 2.1.8 (30), receipt
`testflight/receipts/37839108073`, source
`095048c45a1933ea26de7afd1e05274c1e030344`.
The receipt's status refresh (workflow `38160531995`) records Apple processing
`VALID`, verified EN/RU notes and distribution `IN_BETA_TESTING` / phase
`available`. Apple availability does not establish delivery on Danis's phone.

The comparison from that source to the task's master base
`cee5f0394aafa628029286a59237734da76e16d1` includes two production changes in
`f9fef06`: plain link styling preserves widget name/age colors, and person-page
disappearance resets birthday selection so returning starts another celebration.
Other intervening changes affect test fixtures, App Store assets/tooling, CI,
or documentation. They are omitted from What's New.

PR #40's original full-screen layout was already delivered in master through
PR #49 and is not a new production change in this release. This task reconciles
the old branch with master and adds focused acceptance coverage. Full-screen
layout, photo persistence and editing therefore belong in What to Test.

Danis explicitly requested TestFlight deployment in this task. Before dispatch,
inspect receipts for intervening uploads, compare the final reviewed master source
with the recorded source above, and require its latest CI to pass. The workflow
reserves the actual version/build; these filenames reserve neither.
