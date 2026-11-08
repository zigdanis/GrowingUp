import Foundation

/// Reads the whole library for a backup, and adds a backup's people back into it.
public protocol PeopleBackupGateway: Sendable {
	/// Every person in mosaic order with the photo files their pictures are kept in.
	func snapshot(createdAt: Date, appVersion: String, deviceModel: String) async throws -> LibrarySnapshot
	/// Adds the people of `backup` the library lacks, with their photos, in one save; nobody already here changes. A
	/// failure adds nobody.
	func restore(_ backup: LoadedBackup) async throws -> RestoreSummary
}
