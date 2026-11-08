import Foundation

/// The `manifest.json` of an exported preserved store: what it is, when it was set aside and exported, and every file
/// it holds with its checksum, so a copy can be checked as complete.
struct ArchiveManifest: Codable, Equatable {
	var format = "growingup-preserved-store"
	var formatVersion = 1
	let preservedAt: Date
	let exportedAt: Date
	/// The Core Data error code that made the store incompatible, or 0 and 1 for an unknown or interrupted recovery.
	let cause: Int
	let preservedByAppVersion: String?
	let exportedByAppVersion: String?
	let files: [ArchivedFile]
}
