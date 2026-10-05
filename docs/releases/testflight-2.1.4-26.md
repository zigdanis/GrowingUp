# TestFlight 2.1.4 (26) notes provenance

The app binary is immutable source `b916f38e2dba6dd0f83f0aa8034624b8fcf6bbbf`.
Original release receipt: `testflight/receipts/37272792473`. The upload succeeded
in run `37296774987`; distribution stopped before metadata at the platform prompt.
Run `37297758324` was a **status** operation, so it did not submit the receipt's
EN/RU testing instructions. Those instructions contained no changes summary.

The last TestFlight source tag is `testflight/24`, version 2.1.3 (24), commit
`7e5114bda9c59101e7f9ee9019d4572b5cb3f4e4`. Apple also has 2.1.3 (25), but there
is no source tag or durable receipt tying build 25 to a commit. The subsequent
[public 2.1.3 source release](https://github.com/zigdanis/GrowingUp/releases/tag/2.1.3)
points to `07b5d967cf35c989a384ee17b06043cbb5606788` and has no binary assets.
The notes use that version's verifiable published-source range `2.1.3..b916f38`,
without assuming it is the exact source of build 25.

User-facing changes supported by that range (also present after `testflight/24`):

| Note | Source evidence |
| --- | --- |
| Refreshed person overview and editor | `0cb166b`, `952e634`; `GrowingUp/Presentation/` replaces UIKit scenes |
| Direct crop on photo tap, reliable picker/crop handoff | `fc288fd`, `40559f8`, `5575997`; `ImageCaptureCoordinator.swift` |
| Updated light/dark photo controls | `bd15c5f`, `a3577c5`, `84db9a1`; `GlassButtonChrome.swift`, `PhotoPreviewControls.swift` |
| Saving errors surfaced, old photos preserved on failed edit | `8593ff0`, `549318c`; `CachePersonsGateway.swift`, `PersonEditorPresenter.swift` |

Birth-date persistence, camera capture, widgets and Russian localization already
existed; the testing section asks testers to exercise them without describing
them as new features. Deployment/signing changes and test infrastructure are
omitted from the tester summary.

The adjacent JSON file contains the exact EN/RU text for Apple's build-level
`whatsNew` fields. TestFlight uses one field per locale for both the changes
summary and testing instructions, so the text has two clearly labelled sections.
