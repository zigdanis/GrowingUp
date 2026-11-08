import Foundation

@testable import Core

/// A backup gateway that returns what a test sets, or what `base` holds, and records the backups it was asked to restore.
final class PeopleBackupGatewaySpy: PeopleBackupGateway, @unchecked Sendable {
	var snapshotResult: Result<LibrarySnapshot, Error> = .success(
		LibrarySnapshot(document: BackupDocument(createdAt: Date(), appVersion: "1", deviceModel: "iPhone", people: [], photos: []), photoSources: [:]))
	var restoreResult: Result<RestoreSummary, Error> = .success(
		RestoreSummary(peopleAdded: 1, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true))
	/// A real library whose snapshots this one returns instead of `snapshotResult`.
	var base: PeopleBackupGateway?
	/// How long each snapshot takes, so a test can act while one is under way.
	var snapshotDelay: Duration?
	private(set) var snapshotCount = 0
	private(set) var restored: [BackupDocument] = []

	func snapshot(createdAt: Date, appVersion: String, deviceModel: String) async throws -> LibrarySnapshot {
		snapshotCount += 1
		if let snapshotDelay { try await Task.sleep(for: snapshotDelay) }
		if let base { return try await base.snapshot(createdAt: createdAt, appVersion: appVersion, deviceModel: deviceModel) }
		return try snapshotResult.get()
	}

	func restore(_ backup: LoadedBackup) async throws -> RestoreSummary {
		restored.append(backup.document)
		return try restoreResult.get()
	}
}
