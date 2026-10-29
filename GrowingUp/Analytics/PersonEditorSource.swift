/// Which control opened the in-place edit mode.
enum PersonEditorSource: String, Equatable {
	/// The floating "Add person" button.
	case addButton = "add_button"
	/// The widget's "Add person" link.
	case widget
	/// A tap on a person's page in the viewer.
	case viewer
}
