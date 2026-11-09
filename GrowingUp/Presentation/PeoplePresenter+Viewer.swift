import Core
import Foundation

extension PeoplePresenter {
	/// Whether the mosaic has room for one more person.
	var canAdd: Bool { persons.count < Constants.peopleLimit }

	/// The person `offset` places from the one with `id` in mosaic order, such as the viewer's next page; nil past either
	/// end.
	func neighbour(of id: UUID, by offset: Int) -> UUID? {
		guard let index = persons.firstIndex(where: { $0.id == id }), persons.indices.contains(index + offset) else { return nil }
		return persons[index + offset].id
	}

	/// Returns from the viewer to the mosaic. Edit mode locks the viewer's swipe, so only an accessibility action can get
	/// here while editing; the draft goes with the viewer, as with Cancel.
	func closeViewer() {
		cancelEditing(editMode?.editor)
		isViewing = false
	}
}
