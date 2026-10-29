/// How the in-place edit mode ended.
enum PersonEditorOutcome: String, Equatable {
	case saved
	case cancelled
	case removed
	/// A widget link or a newer session took the cover over.
	case replaced
}
