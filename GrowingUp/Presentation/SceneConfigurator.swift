import Core
import UIKit

@MainActor
struct SceneConfigurator {
	let fetchUseCase: FetchPersonsUseCase
	let addUseCase: AddPersonUseCase
	let editUseCase: EditPersonUseCase
	let removeUseCase: RemovePersonUseCase
	let loadImage: (PersonImage) async throws -> UIImage
	let now: () -> Date
	let photoFixtures: [UIImage]?

	init(
		gateway: PersonsGateway, loadImage: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadImageFromDiskOrMemory,
		now: @escaping () -> Date = Date.init, photoFixtures: [UIImage]? = nil
	) {
		self.loadImage = loadImage
		self.now = now
		self.photoFixtures = photoFixtures
		fetchUseCase = FetchPersonsUseCaseImplementation(personsGateway: gateway)
		addUseCase = AddPersonUseCaseImplementation(personsGateway: gateway)
		editUseCase = EditPersonUseCaseImplementation(personsGateway: gateway)
		removeUseCase = RemovePersonUseCaseImplementation(personsGateway: gateway)
	}

	func editor(
		person: Person?, onMutation: @escaping (PersonMutation) -> Void, onCancel: @escaping () -> Void
	) -> PersonEditorPresenter {
		PersonEditorPresenter(
			person: person, addUseCase: addUseCase, editUseCase: editUseCase,
			removeUseCase: removeUseCase, fetchUseCase: fetchUseCase,
			now: now(), loadImage: loadImage, photoFixtures: photoFixtures, onMutation: onMutation, onCancel: onCancel)
	}

	static func live() -> SceneConfigurator {
		let gateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		return SceneConfigurator(gateway: CachePersonsGateway(coreDataGateway: gateway, imageStore: DiskImageStore()))
	}
}
