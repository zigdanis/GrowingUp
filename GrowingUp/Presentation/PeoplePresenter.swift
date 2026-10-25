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
	/// Whether a long press put the mosaic in reordering, where tiles drag to new places instead of opening the viewer.
	private(set) var isReordering = false
	/// The latest order being stored; each save waits for the one before, so the store ends in the last order shown.
	@ObservationIgnored private var orderSave: Task<Void, Error>?
	/// The `displayOrder` of each person as the store holds it, which a failed save puts the mosaic back to.
	@ObservationIgnored private var storedOrders: [UUID: Int] = [:]
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
			storedOrders = Dictionary(persons.map { ($0.id, $0.displayOrder) }, uniquingKeysWith: { first, _ in first })
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

	/// Opens the full-screen viewer on the person with `id`, such as from their mosaic tile; tiles open nothing while
	/// reordering.
	func view(_ id: UUID) {
		guard !isReordering, persons.contains(where: { $0.id == id }) else { return }
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

	/// Lets the mosaic's tiles be dragged to new places, as a long press on one does.
	func startReordering() {
		guard !persons.isEmpty else { return }
		isReordering = true
	}

	/// Returns the mosaic to opening people from their tiles.
	func finishReordering() { isReordering = false }

	/// Moves the person with `id` to `index` of the mosaic while reordering, such as under a dragged tile; `saveOrder()`
	/// then stores the new order.
	func move(_ id: UUID, to index: Int) {
		guard isReordering, let source = persons.firstIndex(where: { $0.id == id }) else { return }
		let destination = min(max(index, 0), persons.count - 1)
		guard source != destination else { return }
		var reordered = persons
		reordered.insert(reordered.remove(at: source), at: destination)
		persons = reordered
	}

	/// Stores the mosaic's current order, as a dragged tile lands; when the latest save fails, the people return to the order
	/// that is stored. A failed save that a newer one superseded changes nothing: the newer save stores the whole order.
	func saveOrder() async {
		let order = persons.map(\.id)
		guard order != persons.sorted().map(\.id) else { return }
		// The people take their new places at once, so a change saved meanwhile keeps them where they are shown.
		for index in persons.indices {
			persons[index].displayOrder = index + 1
		}
		let previous = orderSave
		let save = Task { [reorderUseCase = configurator.reorderUseCase] in
			_ = await previous?.result
			try await reorderUseCase.reorder(order)
		}
		orderSave = save
		do {
			try await save.value
			for (index, id) in order.enumerated() { storedOrders[id] = index + 1 }
			reloadWidgets()
		} catch {
			guard orderSave == save else { return }
			// Saves are all or nothing and run in turn, so the store holds the order of the last one that succeeded.
			for index in persons.indices {
				persons[index].displayOrder = storedOrders[persons[index].id] ?? persons[index].displayOrder
			}
			persons.sort()
			self.error = SceneError(error)
		}
	}

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
		isReordering = false
		view(target)
	}

	private func showEditor(person: Person?) {
		// The "Add person" link of a widget may arrive while reordering, which the editor ends.
		isReordering = false
		weak var session: PersonEditorPresenter?
		let editor = configurator.editor(
			person: person,
			onMutation: { [weak self] in self?.apply($0, from: session) })
		session = editor
		self.editor = editor
	}

	/// Applies a change that `session`, the editor that made it, has persisted.
	///
	/// The people always take the change, but only the editor still on screen moves the navigation and closes: a widget
	/// link or a newer editor that replaced it while it was saving keeps what it shows.
	func apply(_ mutation: PersonMutation, from session: PersonEditorPresenter?) {
		let ownsNavigation = session != nil && session === editor
		switch mutation {
		case .saved(let person):
			storedOrders[person.id] = person.displayOrder
			if let index = persons.firstIndex(where: { $0.id == person.id }) {
				persons[index] = person
			} else {
				persons.append(person)
				// A new person lands on the mosaic, which scrolls to their new tile.
				if ownsNavigation { isViewing = false }
			}
			persons.sort()
			if ownsNavigation { selectedID = person.id }
		case .removed(let person):
			storedOrders[person.id] = nil
			persons.removeAll { $0.id == person.id }
			// Back on the mosaic, where the missing tile shows what was removed; a neighbour's page would hide it. A viewer
			// a widget link opened on the removed person closes too, as nothing is left to show.
			if ownsNavigation || selectedID == person.id {
				isViewing = false
				selectedID = nil
			}
		}
		if ownsNavigation { editor = nil }
		reloadWidgets()
	}
}
