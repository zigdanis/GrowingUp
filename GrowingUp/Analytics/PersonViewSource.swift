/// How the viewer came to show a person.
enum PersonViewSource: String, Equatable {
	/// A tap on their mosaic tile.
	case tile
	/// A tap on a Home or Lock Screen widget.
	case widget
	/// A swipe, or VoiceOver's "Next person" and "Previous person", from a neighbour's page.
	case swipe
}
