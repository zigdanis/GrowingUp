# Soft Lift TestFlight notes

Prepared before merging PR #108, for the requested next TestFlight release.
English and Russian notes are in soft-lift-testflight-2026-10-28.json.

Notes baseline: latest receipt marked available to testers, 2.2.2 (35),
source b389d0d308fa56d35632b637bba07bed1b228e58. Later uploaded 2.2.3–2.2.5
receipts remain marked awaiting Apple beta review, so the notes include
the user-visible mosaic/editing/photo changes since the available build.
Current master before merge is ce86f6cef9d1b5660738e080f7dcabcebf303df3;
PR #108 adds only the selected icon and its source/provenance records.

Deployment must use the actual merged SHA, with the existing cloud workflow
waiting for that exact source's master CI before archiving/uploading.

## Outcome

PR #106 and PR #108 were merged first; the single release used master
8c6e26364d50b3b662d20f21a8f5cd4043585bd2 with these notes.

- Release run 40766106055 waited for master CI, then archived and uploaded
  TestFlight 2.2.6 (39). It failed afterwards while waiting for Apple
  processing: the runner could not resolve the App Store Connect host.
- Resume run 40777189201 continued the same release without a new upload
  and succeeded. Receipt `testflight/receipts/40766106055` records
  processing `VALID` and distribution `WAITING_FOR_BETA_REVIEW` as of
  29 October 2026.

Availability on Danis's device is unconfirmed until Apple completes beta
review.
