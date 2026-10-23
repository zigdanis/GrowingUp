import Core
import Observation
import WidgetKit

@MainActor
@Observable
final class PeoplePresenter {
	private(set) var persons: [Person] = []
	/// The person the full-screen viewer shows, or last showed, and whose mosaic tile it zooms from and back into.
	///
	/// It outlives the viewer, so a dismissal still knows its tile, and after an add it names the new tile to scroll to.
	private(set) var selectedID: UUID?
	/// Whether the full-screen viewer covers the mosaic; launch always starts on the mosaic.
	var isViewing = false
	var editor: PersonEditorPresenter?
	var error: SceneError?
	private(set) var isLoading = true
	private var pendingWidgetID: UUID?
	private var pendingWidgetIndex: Int?
	private var pendingAdd = false
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
			isLoading = false
			selectWidgetPerson()
			if pendingAdd { addFromWidget() }
		} catch is CancellationError {
		} catch {
			isLoading = false
			// A failed first load must not open the editor or select a person on a later successful one.
			pendingAdd = false
			pendingWidgetIndex = nil
			pendingWidgetID = nil
			self.error = SceneError(error)
		}
	}

	func add() {
		guard canAdd else { return }
		showEditor(person: nil)
	}

	func edit(_ person: Person) { showEditor(person: person) }

	/// Opens the full-screen viewer on the person with `id`, such as from their mosaic tile.
	func view(_ id: UUID) {
		guard persons.contains(where: { $0.id == id }) else { return }
		selectedID = id
		isViewing = true
	}

	/// Follows the viewer's pager to the person with `id`, so the viewer closes into that person's tile.
	func select(_ id: UUID) {
		guard persons.contains(where: { $0.id == id }) else { return }
		selectedID = id
	}

	/// Returns from the viewer to the mosaic.
	func closeViewer() { isViewing = false }

	func open(_ url: URL) {
		if URLComponents(url: url, resolvingAgainstBaseURL: false)?.host == Constants.widgetAddPersonHost {
			// Waits for the people, like a person link, so the editor only opens while there is room for one more.
			pendingAdd = true
			if !isLoading { addFromWidget() }
			return
		}
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
		if let item = components.queryItems?.first(where: { $0.name == Constants.widgetPersonIDKey }) {
			guard let value = item.value, let id = UUID(uuidString: value) else { return }
			pendingWidgetID = id
			pendingWidgetIndex = nil
		} else {
			guard let value = components.queryItems?.first(where: { $0.name == Constants.widgetPersonIndexKey })?.value,
				let index = Int(value), index >= 0
			else { return }
			pendingWidgetIndex = index
			pendingWidgetID = nil
		}
		if !isLoading { selectWidgetPerson() }
	}

	private func addFromWidget() {
		pendingAdd = false
		add()
	}

	private func selectWidgetPerson() {
		let id = pendingWidgetID
		let index = pendingWidgetIndex
		pendingWidgetID = nil
		pendingWidgetIndex = nil
		let target: UUID?
		if let id {
			target = persons.contains(where: { $0.id == id }) ? id : nil
		} else if let index {
			let pinned = persons.filter(\.isOnWidget).sorted()
			target = pinned.indices.contains(index) ? pinned[index].id : nil
		} else {
			target = nil
		}
		guard let target else { return }
		// The person opens over the mosaic, so closing the viewer lands on the mosaic like a tile tap would.
		editor = nil
		view(target)
	}

	private func showEditor(person: Person?) {
		editor = configurator.editor(
			person: person,
			onMutation: { [weak self] in self?.apply($0) })
	}

	func apply(_ mutation: PersonMutation) {
		switch mutation {
		case .saved(let person):
			if let index = persons.firstIndex(where: { $0.id == person.id }) {
				persons[index] = person
			} else {
				persons.append(person)
				// A new person lands on the mosaic, which scrolls to their new tile.
				isViewing = false
			}
			persons.sort()
			selectedID = person.id
		case .removed(let person):
			persons.removeAll { $0.id == person.id }
			// Back on the mosaic, where the missing tile shows what was removed; a neighbour's page would hide it.
			isViewing = false
			selectedID = nil
		}
		editor = nil
		reloadWidgets()
	}
}
