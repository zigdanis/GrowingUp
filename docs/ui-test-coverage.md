# UI journey coverage after the snap

The Glass suite runs 10 journeys instead of 21. The four opt-in App Store capture tests are unchanged and remain skipped in normal journeys. No unit tests were removed; three were added and the countdown matrix was expanded.

Screenshots remain named XCTest attachments, exported with the journey video and result bundle. Human review replaces pixel equality. SnapshotTesting and its transitive packages are removed. Historical App Store capture metadata retains its original input hashes as provenance.

## Coverage map

Names below omit the `test` prefix. Existing unit tests are retained unless explicitly described as added or expanded.

| Previous UI test | Coverage now |
| --- | --- |
| Birthday: LocalizedCountdownThresholdsAndFarOffBirthday | Expanded `OverviewPresenterTests.testBirthdayLineSwitchesUnitsAsMidnightApproaches`: English/Russian days, hours, minutes, seconds, singulars, boundaries and 15-day window; representative Russian countdown in `RussianCountdownPhotoAndPinLimit`. |
| Birthday: LiveMidnightAndEveryBirthdayPageArrival | Added `OverviewPresenterTests.testClockAdvancesFromLiveSecondsThroughMidnightAndRepeatedArrivals`, using an advanced clock without sleeping; existing `SwiftUIPresenterTests.testBirthdayCelebratesVisibleMidnightAndEveryPageArrivalOnly` covers offscreen behavior; `ConfettiStyleTests` covers style rotation. |
| Birthday: ExistingEditorDirtyStateCancelAndExplicitSave | Existing `SwiftUIPresenterTests.testExistingEditorTracksEveryFieldAndRevertedDraft` and `testRemovingEitherStoredPhotoIsDirtyAndUnsavedDraftDoesNotPersist`; cancel/relaunch in `CancelAndRecoverFromSaveFailure`; save/relaunch in `EditPhotoReframeAndPersist`. |
| Birthday: PhotoChangeReframeAndRemovalTrackDirtyState | Existing photo derivation/reframing/removal unit tests; added `PersonEditorPresenterTests.testPickingThenRemovingANewPhotoRestoresTheCleanDraft`; save, reframe, remove and discard interactions merged into `EditPhotoReframeAndPersist`. |
| Birthday: SavedBirthdayEditKeepsTheUpdatedCelebrationAfterTimerTicks | Added `OverviewPresenterTests.testSavedBirthdayMutationUsesTheUpdatedPersonOnEveryClockTick`; editor integration remains in `BirthdayEditAndCelebrationChoice`. |
| Birthday: CelebrateChipControlsConfetti | Chip wiring merged into `BirthdayEditAndCelebrationChoice`; existing `PersonEditorPresenterTests.testCelebrationChoiceIsSaved`, `testExistingPersonBaselineTracksTheCelebrationChoice` and `testOptedOutBirthdayKeepsTheIndicatorWithoutConfetti` cover persistence, opt-out, return and re-enable. |
| Journey: AddAndRelaunch | Retained, including date/time persistence and explicit PM wheel selection, selected-period verification and reachable time wheels after expansion. |
| Journey: CancelAndRecoverFromSaveFailure | Retained, including crop cancellation, discard and relaunch. |
| Journey: DeleteAndRelaunch | Retained; redundant date/time picker interaction removed (covered by AddAndRelaunch). |
| Journey: EditPhotoReframeAndPersist | Moved to `PhotoFramingTests`, starting from seeded data: a tight crop reopens on its framing after a relaunch and zooms back out past it, the circle keeps its own framing, and the removal menu and discarded removal are still checked. `PersonPhotoFramingTests` covers the same flow through the real gateways. |
| Journey: LocalizedPhotoAppearance | Russian form/photo checkpoints merged into `RussianCountdownPhotoAndPinLimit`; English light form/photo covered by editing. |
| Journey: PhotoRemovalMenuTracksEachImage | Merged into `EditPhotoReframeAndPersist`; empty/removed photo state also covered by presenter unit tests. |
| Journey: SeventhPinErrorIsLocalizedInRussian | Merged into `RussianCountdownPhotoAndPinLimit`. |
| Journey: SixPinsPersistAndWidgetLinkSelectsSixthPerson | Sixth-person UUID link merged into `NavigationAvatarsEditorAndWidgetLinks`; `RussianCountdownPhotoAndPinLimit` retains the legacy index URL. Existing pin-capacity/editor tests in `SwiftUIPresenterTests` and `CoreDataPersonsGatewayTests.test_Widget_AllowsSixPeopleAndUnpinningFreesASlot` cover capacity and persistence. `SwiftUIPresenterTests` verifies cold/warm UUID links, unpinned targets, stale/invalid UUIDs and legacy index fallback; `WidgetPersonLoaderTests.testFirstPinnedPersonInCreationOrderHasStableDeepLink` verifies generated UUID URLs. |
| Journey: WidgetSizesRenderPinnedPeopleInBothLanguages | Three families with 1/3/6 people in `HomeScreenWidgetSizes`; Russian large widget captions in `RussianCountdownPhotoAndPinLimit`; existing `WidgetPersonLoaderTests` and `PersonTileContentTests` cover ordering, counts and localized content. |
| Lock screen: RenderTheFirstPinnedPersonInBothLanguages | Circular first-person rendering merged into `LockScreenWidgetFamiliesAndStates`; existing `WidgetPersonLoaderTests` and `LockScreenTextTests` cover first-person selection and localized text. |
| Lock screen: CelebrateTheFirstPinnedBirthday | Russian rectangular birthday merged into `LockScreenWidgetFamiliesAndStates`; existing `LockScreenTextTests` cover birthday/ring/inline text in both languages. |
| Lock screen: InviteToAddSomeoneWhenNobodyIsPinned | Inline empty invitation merged into `LockScreenWidgetFamiliesAndStates`; existing `WidgetPersonLoaderTests.testNobodyPinnedOrFailedFetchLoadsNobody` covers empty state. |
| Navigation: AvatarStripSwitchesPeopleAndOpensTheAddPage | Merged into `NavigationAvatarsEditorAndWidgetLinks`. |
| Navigation: LongPressOnThePhotoAndTheEditButtonOpenTheEditor | Merged into `NavigationAvatarsEditorAndWidgetLinks`. |
| Removal: RemovalConfirmationStaysNearButton | Retained once in English/light, including Glass anchoring geometry. |

## Intentionally dropped assertions/permutations

- Pixel equality, controls-region comparisons and reference PNGs: nondeterministic system rendering caused false failures; named attachments remain reviewable.
- Exact confetti visibility windows and UI screenshots for all three animated styles: transient animation queries race the simulator; deterministic presenter/style tests cover triggering, suppression and rotation.
- Every home-widget size × language × appearance combination: repeated launches add little signal; all sizes, both appearances, and Russian captions remain represented.
- Every lock-screen family × ordinary/birthday/empty × language combination: one representative per family/state is sufficient alongside the localized text and loader unit tests.
- Russian removal-confirmation geometry: the retained English case verifies the same anchor; the Russian journey covers localization elsewhere.
- Repeated English pin-limit UI error: presenter and Core Data unit tests cover rejection; Russian UI verifies the error reaches the user.
- Creating pins four through six through repeated UI saves: unit tests cover each capacity boundary and persistence; seeded six-person navigation verifies the UUID deep-link route, with legacy index parsing covered by the Russian journey.
