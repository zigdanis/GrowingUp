# Birthday and editor release notes

Prepared notes: [birthday-editing.json](birthday-editing.json).

Previous processed upload: TestFlight 2.1.7 (29), receipt
`testflight/receipts/37481146627`, source
`de3c1371ae1697c103bae657719c5e67d12785ec`.
The recorded Apple processing state is `VALID`, EN/RU notes are verified, and
the last recorded external distribution state is `WAITING_FOR_BETA_REVIEW`.
This records a processed upload; it does not establish delivery on a device.

The initial task base is `c45701e`. Its diff from the previous upload changes
workflow documentation only. This release adds the birthday indicator and live
countdown, native confetti, and change-aware editor saving. Birthday celebrations
start at local midnight and last for the calendar day. February 29 anniversaries
fall on February 28 in non-leap years.

Danis explicitly authorized merging the verified task PR and deploying this update
to TestFlight in the active task. This authorization belongs to this release.
Before dispatch, compare the final reviewed master source against the previous
upload, inspect receipts for intervening releases, and wait for source CI to pass.
The workflow reserves the actual version and build; this filename reserves neither.
