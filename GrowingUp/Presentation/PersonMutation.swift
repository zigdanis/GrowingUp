import Core

enum PersonMutation {
	case saved(Person)
	case removed(Person)

	/// The person as saved, or as they were before their removal.
	var person: Person {
		switch self {
		case .saved(let person), .removed(let person): person
		}
	}

	/// The product event of this change once it landed: `previous` is the person as stored before it and `people` are
	/// everyone stored after it.
	func analyticsEvent(previous: Person?, people: [Person]) -> AnalyticsEvent {
		switch self {
		case .saved(let person): .personSaved(PersonSavedProperties(saved: person, previous: previous, people: people))
		case .removed: .personRemoved(peopleCount: people.count)
		}
	}

	/// How the editing session that made this change ends.
	var editorOutcome: PersonEditorOutcome {
		switch self {
		case .saved: .saved
		case .removed: .removed
		}
	}
}
