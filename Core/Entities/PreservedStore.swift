import Foundation

/// An earlier people library that this version of the app could not open, kept aside unchanged by store recovery
/// together with the photos it showed; see `PreservedStoreLibrary`.
public struct PreservedStore: Hashable, Sendable, Identifiable {
	/// The name of the folder that holds it, unique per recovery.
	public let id: String
	/// When it was set aside.
	public let preservedAt: Date
	public let cause: PreservedStoreCause
	/// The version of the app that could not open it, if it noted one.
	public let appVersion: String?
	/// Whether its photos are kept with it; until then they are only the loose files the active library may also use.
	public let hasPreservedPhotos: Bool
	/// Whether the app has reported this recovery to crash reporting, which it does once.
	public let isReported: Bool
	/// The bytes its folder holds: the SQLite files and the photos kept with it.
	public let byteCount: Int64

	public init(
		id: String, preservedAt: Date, cause: PreservedStoreCause, appVersion: String?, hasPreservedPhotos: Bool, isReported: Bool,
		byteCount: Int64 = 0
	) {
		self.id = id
		self.preservedAt = preservedAt
		self.cause = cause
		self.appVersion = appVersion
		self.hasPreservedPhotos = hasPreservedPhotos
		self.isReported = isReported
		self.byteCount = byteCount
	}
}
