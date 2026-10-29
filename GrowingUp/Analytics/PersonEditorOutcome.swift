/// How the in-place edit mode ended.
enum PersonEditorOutcome: String, Equatable {
	case saved
	case cancelled
	case removed
}
