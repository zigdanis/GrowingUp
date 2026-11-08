/// What a restore did: it only ever adds people, so the rest of the backup was either here already or did not fit.
public struct RestoreSummary: Equatable, Sendable {
	public var peopleAdded: Int
	/// People of the backup the app already has, by identifier, or by name and day of birth.
	public var peopleAlreadyPresent: Int
	/// People left out because the app keeps at most `Constants.peopleLimit`.
	public var peopleOverLimit: Int
	/// Whether the library was empty before, as after a reinstall.
	public var intoEmptyLibrary: Bool

	public init(peopleAdded: Int, peopleAlreadyPresent: Int, peopleOverLimit: Int, intoEmptyLibrary: Bool) {
		self.peopleAdded = peopleAdded
		self.peopleAlreadyPresent = peopleAlreadyPresent
		self.peopleOverLimit = peopleOverLimit
		self.intoEmptyLibrary = intoEmptyLibrary
	}

	public var addedAnything: Bool { peopleAdded > 0 }
}
