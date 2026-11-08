import Core
import Foundation
import Observation
import UIKit

/// Settings' Backup: "Export all data" writes every person and photo to one file for the share sheet, "Import from file"
/// reads such a file and, once the person confirms, adds whoever the app lacks, and with an iCloud backup, its list of
/// backups and the empty mosaic's offer restore from iCloud the same way. A restore never changes or deletes anyone.
@MainActor
@Observable
final class BackupPresenter {
	private(set) var export: FileExport = .idle
	/// Whether a picked file is being read.
	private(set) var isReading = false
	/// A backup read and checked, waiting for the person's confirmation.
	var pendingRestore: PendingRestore?
	private(set) var isRestoring = false
	/// The iCloud backup being loaded to restore, by `BackupCandidate.id`.
	private(set) var loadingCandidateID: String?
	var alert: BackupAlert?
	/// The library's backup in iCloud; nil where there is none, as in tests, previews and UI-test launches.
	@ObservationIgnored let iCloud: ICloudBackupService?
	@ObservationIgnored private let gateway: PeopleBackupGateway?
	@ObservationIgnored private let archive: BackupArchive
	@ObservationIgnored private let analytics: AnalyticsGateway
	/// Whether the people are loaded; until then nothing can be exported or restored next to them.
	@ObservationIgnored private let isLibraryLoaded: () -> Bool
	/// Shows the people a restore added.
	@ObservationIgnored private let libraryRestored: () async -> Void
	@ObservationIgnored private let now: () -> Date
	/// Counts exports, so one the sheet abandoned while it was written cleans up instead of opening the share sheet.
	@ObservationIgnored private var exportGeneration = 0
	/// Counts imports the same way, so a file read for a closed sheet never asks to be restored later.
	@ObservationIgnored private var importGeneration = 0
	/// The restore under way, which tests wait for.
	@ObservationIgnored private(set) var restoreTask: Task<Void, Never>?

	init(
		gateway: PeopleBackupGateway?, iCloud: ICloudBackupService? = nil, archive: BackupArchive = .temporary,
		analytics: AnalyticsGateway, isLibraryLoaded: @escaping () -> Bool, libraryRestored: @escaping () async -> Void,
		now: @escaping () -> Date = Date.init
	) {
		self.gateway = gateway
		self.iCloud = iCloud
		self.archive = archive
		self.analytics = analytics
		self.isLibraryLoaded = isLibraryLoaded
		self.libraryRestored = libraryRestored
		self.now = now
	}

	var isAvailable: Bool { gateway != nil && isLibraryLoaded() }
	var isBusy: Bool { export == .preparing || isReading || isRestoring || loadingCandidateID != nil }

	// MARK: - Export

	/// Writes the whole library as one file for the share sheet.
	func startExport() async {
		guard let gateway, isLibraryLoaded(), !isBusy else { return }
		export = .preparing
		exportGeneration += 1
		let generation = exportGeneration
		let createdAt = now()
		let archive = archive
		let result: Result<(URL, Int), Error>
		do {
			let snapshot = try await gateway.snapshot(createdAt: createdAt, appVersion: Self.appVersion, deviceModel: Self.deviceModel)
			result = await Task.detached(priority: .userInitiated) {
				Result { (try archive.export(snapshot), snapshot.document.people.count) }
			}.value
		} catch {
			result = .failure(error)
		}
		guard generation == exportGeneration else {
			// The sheet closed meanwhile: nothing opens the file, so it goes.
			archive.removeExports()
			export = .idle
			return
		}
		switch result {
		case .success(let (url, peopleCount)):
			export = .ready(url)
			analytics.track(.dataExported(peopleCount: peopleCount))
		case .failure(let error):
			export = .idle
			alert = .exportFailed
			analytics.report(AnalyticsFailure(operation: "export_data", error: error))
		}
	}

	/// Forgets the file once the share sheet closed, and removes it from the device's temporary files.
	func finishExport() {
		guard export != .preparing else { return }
		export = .idle
		archive.removeExports()
	}

	// MARK: - Import

	/// Reads the backup file the person picked and asks to confirm the restore.
	func open(pickedFile url: URL) async {
		guard gateway != nil, isLibraryLoaded(), !isBusy else { return }
		isReading = true
		pendingRestore = nil
		importGeneration += 1
		let generation = importGeneration
		let archive = archive
		let result = await Task.detached(priority: .userInitiated) { Result { try archive.openPicked(url) } }.value
		isReading = false
		guard generation == importGeneration else {
			// The sheet closed meanwhile: nobody is left to confirm the restore.
			archive.removeImports()
			return
		}
		switch result {
		case .success(let backup):
			pendingRestore = PendingRestore(backup: backup, source: .file)
		case .failure(let error):
			archive.removeImports()
			alert = .unreadable(error as? BackupError)
			// A file that is no backup is the person's pick, not the app's failure.
			if error as? BackupError == nil {
				analytics.report(AnalyticsFailure(operation: "import_data", error: error))
			}
		}
	}

	// MARK: - iCloud

	/// The backup the empty mosaic offers to restore, while the iCloud backup is on and the people are loaded.
	var restoreOffer: BackupCandidate? {
		guard gateway != nil, isLibraryLoaded() else { return nil }
		return iCloud?.restoreOffer
	}

	/// An empty library may be a reinstall: looks in iCloud for a backup to offer, as at launch and on return to the app.
	func lookForBackupToRestore(libraryIsEmpty: Bool) async {
		guard libraryIsEmpty, gateway != nil, isLibraryLoaded(), let iCloud, iCloud.isEnabled, !iCloud.isRestoreOfferDismissed
		else { return }
		await iCloud.refreshCandidates()
	}

	/// Loads a backup picked in the list of iCloud backups and asks to confirm the restore.
	func open(_ candidate: BackupCandidate) async {
		let generation = importGeneration
		guard let backup = await load(candidate) else { return }
		// Settings closed meanwhile: nobody is left to confirm the restore.
		guard generation == importGeneration else {
			archive.removeImports()
			return
		}
		pendingRestore = PendingRestore(backup: backup, source: .icloud)
	}

	/// Restores the backup the empty mosaic offers, whose card is the confirmation.
	func restoreOffered(_ candidate: BackupCandidate) async {
		guard let backup = await load(candidate) else { return }
		await confirmRestore(PendingRestore(backup: backup, source: .icloud))?.value
	}

	/// The backup `candidate` stands for with every photo checked; nil, with the alert saying why, when it can't be
	/// loaded whole. A photo iCloud could not download fails the load: restoring without it would lose it for good.
	private func load(_ candidate: BackupCandidate) async -> LoadedBackup? {
		guard gateway != nil, let iCloud, isLibraryLoaded(), !isBusy else { return nil }
		loadingCandidateID = candidate.id
		defer { loadingCandidateID = nil }
		pendingRestore = nil
		do {
			return try await iCloud.loadBackup(candidate, stagingDirectory: archive.stagingFolder())
		} catch {
			archive.removeImports()
			alert = .iCloudUnreadable(error as? BackupError)
			return nil
		}
	}

	/// Removes a backup from iCloud, as the list's swipe and its confirmation ask; the people in the app stay as they are.
	func delete(_ candidate: BackupCandidate) async {
		guard let iCloud else { return }
		do {
			try await iCloud.deleteBackup(candidate)
		} catch {
			alert = .deleteFailed
			analytics.report(AnalyticsFailure(operation: "delete_backup", error: error))
		}
	}

	// MARK: - Restore

	/// Starts adding the people of the confirmed backup that the library lacks. The restore owns the backup's files from
	/// this moment, so the confirmation closing afterwards can't take them away.
	@discardableResult
	func confirmRestore(_ pending: PendingRestore) -> Task<Void, Never>? {
		guard let gateway, !isRestoring else { return nil }
		pendingRestore = nil
		// Restoring next to people that could not be read would match them against nothing.
		guard isLibraryLoaded() else {
			alert = .restoreFailed
			archive.removeImports()
			return nil
		}
		isRestoring = true
		let task = Task { await restore(pending, with: gateway) }
		restoreTask = task
		return task
	}

	private func restore(_ pending: PendingRestore, with gateway: PeopleBackupGateway) async {
		defer {
			isRestoring = false
			archive.removeImports()
		}
		do {
			let summary = try await gateway.restore(pending.backup)
			await libraryRestored()
			alert = .restored(summary)
			analytics.track(
				.dataRestored(
					source: pending.source, peopleAdded: summary.peopleAdded, peopleAlreadyPresent: summary.peopleAlreadyPresent,
					peopleOverLimit: summary.peopleOverLimit, intoEmptyLibrary: summary.intoEmptyLibrary))
		} catch {
			alert = .restoreFailed
			analytics.report(AnalyticsFailure(operation: "restore_backup", error: error))
		}
	}

	/// The confirmation closed: its own buttons say whether to restore, so this only forgets the question.
	func dismissRestoreConfirmation() {
		pendingRestore = nil
	}

	/// The person chose not to restore the backup they picked; its unpacked files go.
	func cancelRestore() {
		pendingRestore = nil
		if !isReading, !isRestoring { archive.removeImports() }
	}

	/// Drops what the sheet left when it closes: a finished export goes now, one still being written as soon as it is
	/// done; a file still being read is never offered, and a backup waiting for confirmation is not restored. A restore
	/// under way finishes.
	func abandon() {
		exportGeneration += 1
		importGeneration += 1
		pendingRestore = nil
		if export != .preparing {
			export = .idle
			archive.removeExports()
		}
		if !isReading, !isRestoring { archive.removeImports() }
	}

	/// The version and build that writes a backup, such as `3.2 (50)`.
	static var appVersion: String { AppVersion.current.display }

	/// The kind of device, such as `iPhone` or `iPad`; never its name.
	static var deviceModel: String { UIDevice.current.model }
}
