enum UITestSeed: String, Codable {
	case empty
	case pinned
	case sixPinned
	/// The first four of `sixPinned`, which a large widget lays out as two rows of two.
	case fourPinned
	case birthdays
	/// Alice alone, without a photo, so removing her empties the mosaic.
	case onePerson
}
