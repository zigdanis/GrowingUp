enum UITestSeed: String, Codable {
	case empty
	case pinned
	case sixPinned
	/// The first four of `sixPinned`, which a large widget lays out as two rows of two.
	case fourPinned
	case birthdays
	/// Alice alone, without a photo, so removing her empties the mosaic.
	case onePerson
	/// The App Store demo people, Mia, Leo, Mango and Teddy, pinned with the demo photos, for layout captures.
	case demo
	/// Mia alone, as in `demo`, for a mosaic of one.
	case demoMia
}
