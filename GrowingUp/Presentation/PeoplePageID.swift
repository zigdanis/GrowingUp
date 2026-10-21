import Foundation

/// A page of the people pager: a person's page, or the add page after the last person.
///
/// The pager's scroll position uses nil for "no page", while the presenter selects the add page with a nil person,
/// so the add page needs an identity of its own.
enum PeoplePageID: Hashable {
	case person(UUID)
	case add

	/// The page the presenter's selection shows.
	init(selectedID: UUID?) {
		self = selectedID.map(Self.person) ?? .add
	}

	/// The selection that shows this page: the person, or nil for the add page.
	var selectedID: UUID? {
		guard case .person(let id) = self else { return nil }
		return id
	}
}
