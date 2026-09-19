import Core
import Observation
import UIKit
import WidgetKit

@MainActor
@Observable
final class PeoplePresenter {
	private(set) var persons: [Person] = []
	var selectedID: UUID?
	var editor: PersonEditorPresenter?
	var error: SceneError?
	private(set) var isLoading = true
	private var pendingWidgetIndex: Int?
	let configurator: SceneConfigurator
	private let reloadWidgets: () -> Void

	init(
		configurator: SceneConfigurator,
		reloadWidgets: @escaping () -> Void = {
			WidgetCenter.shared.reloadAllTimelines()
		}
	) {
		self.configurator = configurator
		self.reloadWidgets = reloadWidgets
	}

	var canAdd: Bool { persons.count < 20 }

	func load() async {
		do {
			persons = try await configurator.fetchUseCase.fetchPersons().sorted()
			if selectedID == nil { selectedID = persons.first?.id }
			isLoading = false
			if let pendingWidgetIndex { selectWidgetPerson(index: pendingWidgetIndex) }
		} catch is CancellationError {
		} catch {
			isLoading = false
			self.error = SceneError(error)
		}
	}

	func add() {
		guard canAdd else { return }
		showEditor(person: nil)
	}

	func edit(_ person: Person) { showEditor(person: person) }

	func open(_ url: URL) {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			let value = components.queryItems?.first(where: { $0.name == Constants.widgetPersonIndexKey })?.value,
			let index = Int(value), index >= 0
		else { return }
		pendingWidgetIndex = index
		if !isLoading { selectWidgetPerson(index: index) }
	}

	private func selectWidgetPerson(index: Int) {
		pendingWidgetIndex = nil
		let pinned = persons.filter(\.isOnWidget).sorted()
		guard pinned.indices.contains(index) else { return }
		editor = nil
		selectedID = pinned[index].id
	}

	private func showEditor(person: Person?) {
		editor = configurator.editor(
			person: person,
			onMutation: { [weak self] in self?.apply($0) },
			onCancel: { [weak self] in self?.editor = nil })
	}

	func apply(_ mutation: PersonMutation) {
		switch mutation {
		case .saved(let person):
			if let index = persons.firstIndex(where: { $0.id == person.id }) {
				persons[index] = person
			} else {
				persons.append(person)
			}
			persons.sort()
			selectedID = person.id
		case .removed(let person):
			let index = persons.firstIndex(where: { $0.id == person.id }) ?? 0
			persons.removeAll { $0.id == person.id }
			selectedID = persons.isEmpty ? nil : persons[min(index, persons.count - 1)].id
		}
		editor = nil
		reloadWidgets()
	}
}

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
