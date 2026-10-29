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

	/// The product events of this change once it landed: `previous` is the person as stored before it and `people` are
	/// everyone stored after it. A change that closed `closedEditor`, the open editing session, also ends that session.
	func analyticsEvents(previous: Person?, people: [Person], closedEditor: PersonEditorPresenter?) -> [AnalyticsEvent] {
		var events: [AnalyticsEvent]
		let outcome: PersonEditorOutcome
		switch self {
		case .saved(let person):
			events = [.personSaved(PersonSavedProperties(saved: person, previous: previous, people: people))]
			outcome = .saved
		case .removed:
			events = [.personRemoved(peopleCount: people.count)]
			outcome = .removed
		}
		if let closedEditor {
			events.append(.personEditorClosed(isNewPerson: closedEditor.person == nil, outcome: outcome))
		}
		return events
	}
}
