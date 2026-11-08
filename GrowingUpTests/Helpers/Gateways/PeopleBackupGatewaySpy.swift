import Foundation

@testable import Core

/// A backup gateway that returns what a test sets and records the backups it was asked to restore.
final class PeopleBackupGatewaySpy: PeopleBackupGateway, @unchecked Sendable {
	var snapshotResult: Result<LibrarySnapshot, Error> = .success(
		LibrarySnapshot(document: BackupDocument(createdAt: Date(), appVersion: "1", deviceModel: "iPhone", people: [], photos: []), photoSources: [:]))
	var restoreResult: Result<RestoreSummary, Error> = .success(
		RestoreSummary(peopleAdded: 1, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true))
	private(set) var restored: [BackupDocument] = []

	func snapshot(createdAt: Date, appVersion: String, deviceModel: String) async throws -> LibrarySnapshot {
		try snapshotResult.get()
	}

	func restore(_ backup: LoadedBackup) async throws -> RestoreSummary {
		restored.append(backup.document)
		return try restoreResult.get()
	}
}
