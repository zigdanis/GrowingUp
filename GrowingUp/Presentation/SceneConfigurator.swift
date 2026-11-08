import Core
import UIKit

@MainActor
struct SceneConfigurator {
	let fetchUseCase: FetchPersonsUseCase
	let addUseCase: AddPersonUseCase
	let editUseCase: EditPersonUseCase
	let removeUseCase: RemovePersonUseCase
	let reorderUseCase: ReorderPersonsUseCase
	let loadImage: (PersonImage) async throws -> UIImage
	/// Decodes a person's stored original at its full size, for framing their pictures.
	let loadOriginal: (PersonImage) async throws -> UIImage
	/// Decodes a stored picture to a thumbnail whose longer side is at most the given pixels, without caching the original.
	let loadThumbnail: (PersonImage, Int) async throws -> UIImage
	let now: () -> Date
	let photoFixtures: [UIImage]?
	/// Product events and handled failures; silent in tests, previews and UI-test launches.
	let analytics: AnalyticsGateway
	/// Times the App Store rating request; nil where the app never asks: tests, previews and verification launches.
	let reviewPrompter: ReviewPrompter?
	/// The earlier libraries store recovery set aside; nil where there are none to find: tests, previews and UI tests.
	let preservedStores: PreservedStoreGateway?
	/// Reads the whole library for an export and adds a backup's people back; nil where the Backup sheet offers neither.
	let backup: PeopleBackupGateway?
	/// Shows the Home Screen widget hint on the mosaic; nil where it never shows: tests, previews and verification
	/// launches other than `GROWINGUP_WIDGET_HINT=force`.
	let widgetHinter: WidgetHinter?

	init(
		gateway: PersonsGateway, loadImage: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadImageFromDiskOrMemory,
		loadOriginal: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadOriginal,
		loadThumbnail: @escaping (PersonImage, Int) async throws -> UIImage = ImagesCache.loadThumbnail,
		now: @escaping () -> Date = Date.init, photoFixtures: [UIImage]? = nil, analytics: AnalyticsGateway = NoopAnalyticsGateway(),
		reviewPrompter: ReviewPrompter? = nil, preservedStores: PreservedStoreGateway? = nil, backup: PeopleBackupGateway? = nil,
		widgetHinter: WidgetHinter? = nil
	) {
		self.analytics = analytics
		self.preservedStores = preservedStores
		self.backup = backup
		self.reviewPrompter = reviewPrompter
		self.widgetHinter = widgetHinter
		self.loadImage = loadImage
		self.loadOriginal = loadOriginal
		self.loadThumbnail = loadThumbnail
		self.now = now
		self.photoFixtures = photoFixtures
		fetchUseCase = FetchPersonsUseCaseImplementation(personsGateway: gateway)
		addUseCase = AddPersonUseCaseImplementation(personsGateway: gateway)
		editUseCase = EditPersonUseCaseImplementation(personsGateway: gateway)
		removeUseCase = RemovePersonUseCaseImplementation(personsGateway: gateway)
		reorderUseCase = ReorderPersonsUseCaseImplementation(personsGateway: gateway)
	}

	func editor(
		person: Person?, onMutation: @escaping (PersonMutation) -> Void
	) -> PersonEditorPresenter {
		PersonEditorPresenter(
			person: person, addUseCase: addUseCase, editUseCase: editUseCase,
			removeUseCase: removeUseCase, fetchUseCase: fetchUseCase,
			now: now(), loadImage: loadImage, loadOriginal: loadOriginal, photoFixtures: photoFixtures, analytics: analytics,
			onError: { [weak reviewPrompter, weak widgetHinter] in
				reviewPrompter?.noteSetback()
				widgetHinter?.noteSetback()
			}, onMutation: onMutation)
	}

	/// An alert or a removal: the session is no moment for a rating request or the widget hint.
	func noteSetback() {
		reviewPrompter?.noteSetback()
		widgetHinter?.noteSetback()
	}

	static func live(analytics: AnalyticsGateway) -> SceneConfigurator {
		let gateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		let reviewStore = ReviewPromptStore()
		let reviewPrompter = ReviewPromptMode.current().map { ReviewPrompter(store: reviewStore, mode: $0) }
		// The hint counts days and visits as the rating prompt stores them.
		let widgetHinter = WidgetHintMode.current().map {
			WidgetHinter(
				store: WidgetHintStore(), usage: { reviewStore.state }, mode: $0,
				lookUpWidget: InstalledWidgetLookup.isHomeScreenWidgetInstalled, analytics: analytics)
		}
		return SceneConfigurator(
			gateway: CachePersonsGateway(coreDataGateway: gateway, imageStore: DiskImageStore()), analytics: analytics,
			reviewPrompter: reviewPrompter, preservedStores: try? PreservedStoreLibrary.shared(), backup: try? CoreDataPeopleBackupGateway.shared(),
			widgetHinter: widgetHinter)
	}
}
