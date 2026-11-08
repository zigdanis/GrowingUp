/// What the app knows about the people it stores: only a read that succeeded can tell an empty library from one it
/// could not open.
enum PeopleLibraryState: Equatable {
	/// The first read is under way.
	case loading
	/// A read succeeded; from then on the presenter keeps the people up to date itself.
	case loaded
	/// No read has succeeded yet, so the people are unknown rather than none; `isRetrying` while another read is under
	/// way.
	case unavailable(isRetrying: Bool)
}
