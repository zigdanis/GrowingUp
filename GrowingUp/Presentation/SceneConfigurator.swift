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

	init(
		gateway: PersonsGateway, loadImage: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadImageFromDiskOrMemory,
		loadOriginal: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadOriginal,
		loadThumbnail: @escaping (PersonImage, Int) async throws -> UIImage = ImagesCache.loadThumbnail,
		now: @escaping () -> Date = Date.init, photoFixtures: [UIImage]? = nil
	) {
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
			now: now(), loadImage: loadImage, loadOriginal: loadOriginal, photoFixtures: photoFixtures, onMutation: onMutation)
	}

	static func live() -> SceneConfigurator {
		let gateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		return SceneConfigurator(gateway: CachePersonsGateway(coreDataGateway: gateway, imageStore: DiskImageStore()))
	}
}
