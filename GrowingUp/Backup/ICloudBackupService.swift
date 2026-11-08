import Core
import Foundation
import Observation
import UIKit

/// Keeps a copy of the library in the person's iCloud, so deleting the app or changing phones does not lose it.
///
/// A few seconds after each change, and at once when the app goes to the background, it writes this install's backup
/// with `BackupFolderStore`, unless the library is as the intact backup holds it already. iCloud uploads the files in its
/// own time; `uploadState` says whether it has. Nothing is written before the people have loaded or while loading fails,
/// nor an empty library on an install with no backup yet, so a fresh install never puts an empty backup next to the one
/// it should restore. It also lists the backups in iCloud to restore from.
@MainActor
@Observable
final class ICloudBackupService {
	private(set) var availability: ICloudBackupAvailability = .checking
	private(set) var isEnabled: Bool
	private(set) var isBackingUp = false
	private(set) var lastBackupAt: Date?
	private(set) var uploadState: BackupUploadState?
	/// The last attempt to write the backup failed, as when the device is out of space.
	private(set) var lastWriteFailed = false
	/// Every backup found in iCloud, newest first, after `refreshCandidates()`.
	private(set) var candidates: [BackupCandidate] = []
	private(set) var isLoadingCandidates = false
	/// The person chose "Not now" on the empty mosaic's offer; Settings still lists every backup.
	private(set) var isRestoreOfferDismissed: Bool

	@ObservationIgnored private let settings: BackupSettings
	@ObservationIgnored private let gateway: PeopleBackupGateway
	@ObservationIgnored private let analytics: AnalyticsGateway
	/// Writes a few seconds after the last change, one write at a time.
	@ObservationIgnored private let passes: BackupPassScheduler
	@ObservationIgnored private let locateStore: () async -> BackupFolderStore?
	@ObservationIgnored private let discoverFolders: () async -> Set<String>
	/// The iCloud account's `ubiquityIdentityToken`; nil without one or in tests.
	@ObservationIgnored private let accountIdentity: () -> NSObject?
	@ObservationIgnored private let now: () -> Date
	@ObservationIgnored private let appVersion: String
	@ObservationIgnored private let deviceModel: String
	@ObservationIgnored private var isLibraryLoaded: () -> Bool = { false }
	@ObservationIgnored private var store: BackupFolderStore?
	@ObservationIgnored private var locating: Task<Void, Never>?
	/// Changes with the iCloud account, so a write that started for the previous account can't mark the new one as
	/// backed up.
	@ObservationIgnored private var storeGeneration = 0
	@ObservationIgnored private var hasReportedReadFailure = false
	@ObservationIgnored private var hasReportedWriteFailure = false
	@ObservationIgnored private var uploadCheck: Task<Void, Never>?
	@ObservationIgnored private var identityObserver: NSObjectProtocol?

	/// - Parameters:
	///   - locateStore: The backups' folder, or nil when iCloud is not available; asked again after the account changes.
	///   - discoverFolders: The install folders iCloud knows of, including ones not downloaded yet.
	///   - deviceModel: The kind of device a backup names; `UIDevice.model` when nil.
	init(
		settings: BackupSettings, gateway: PeopleBackupGateway, analytics: AnalyticsGateway, debounce: Duration = .seconds(3),
		observesAccountChanges: Bool = false, locateStore: @escaping () async -> BackupFolderStore?,
		discoverFolders: @escaping () async -> Set<String> = { [] }, accountIdentity: @escaping () -> NSObject? = { nil },
		now: @escaping () -> Date = Date.init, appVersion: String = AppVersion.current.display,
		deviceModel: String? = nil
	) {
		self.settings = settings
		self.gateway = gateway
		self.analytics = analytics
		passes = BackupPassScheduler(delay: debounce)
		self.locateStore = locateStore
		self.discoverFolders = discoverFolders
		self.accountIdentity = accountIdentity
		self.now = now
		self.appVersion = appVersion
		self.deviceModel = deviceModel ?? UIDevice.current.model
		isEnabled = settings.isEnabled
		lastBackupAt = settings.lastBackupAt
		isRestoreOfferDismissed = settings.isRestoreOfferDismissed
		passes.pass = { [weak self] in await self?.writeBackupOnce() }
		if observesAccountChanges {
			identityObserver = NotificationCenter.default.addObserver(
				forName: .NSUbiquityIdentityDidChange, object: nil, queue: .main
			) { [weak self] _ in
				MainActor.assumeIsolated { self?.accountChanged() }
			}
		}
	}

	/// Connects the library, whose people must be loaded before anything is written, and makes the first backup of this
	/// launch once iCloud is found.
	@discardableResult
	func start(isLibraryLoaded: @escaping () -> Bool) -> Task<Void, Never> {
		self.isLibraryLoaded = isLibraryLoaded
		return Task {
			await locateStoreIfNeeded()
			libraryChanged()
		}
	}

	// MARK: - Backing up

	/// The library changed: back up once the changes stop for a moment.
	func libraryChanged() {
		guard isEnabled, availability != .unavailable else { return }
		passes.schedule()
	}

	/// The app is going to the background: writes a waiting backup now instead of after the pause, and lets a write under
	/// way finish, while iOS allows.
	func flushPendingBackup() {
		guard passes.hasWork else { return }
		let application = UIApplication.shared
		var taskID = UIBackgroundTaskIdentifier.invalid
		taskID = application.beginBackgroundTask(withName: "iCloud backup") {
			application.endBackgroundTask(taskID)
			taskID = .invalid
		}
		Task {
			await backUpNow()
			if taskID != .invalid { application.endBackgroundTask(taskID) }
		}
	}

	/// Writes the backup now. A call while a write runs waits for it and one more pass, so the backup always ends up with
	/// the library as it was when the last call came.
	func backUpNow() async {
		await passes.runNow()
		watchUpload()
	}

	private func writeBackupOnce() async {
		guard isEnabled, let store, isLibraryLoaded() else { return }
		isBackingUp = true
		defer { isBackingUp = false }
		let generation = storeGeneration
		let snapshot: LibrarySnapshot
		do {
			snapshot = try await gateway.snapshot(createdAt: now(), appVersion: appVersion, deviceModel: deviceModel)
		} catch {
			report(error, operation: "read_backup", once: &hasReportedReadFailure)
			return
		}
		// The account changed, or the backup was turned off, while the library was read.
		guard generation == storeGeneration, isEnabled else { return }
		let folder = store.folder(for: settings.writerID)
		let lastHash = settings.lastContentHash
		let outcome = await Task.detached(priority: .utility) {
			Result { try Self.write(snapshot, to: folder, lastHash: lastHash) }
		}.value
		// A write for the previous account must not mark the new one as backed up.
		guard generation == storeGeneration else { return }
		// After every pass, scheduled or not: iCloud may still be uploading, or may refuse the upload.
		defer { watchUpload() }
		switch outcome {
		case .success(.written(let hash)):
			settings.lastContentHash = hash
			settings.lastBackupAt = snapshot.document.createdAt
			lastBackupAt = snapshot.document.createdAt
			lastWriteFailed = false
		case .success(.skipped):
			// Nothing in iCloud for this install: no "Last backup" to show.
			settings.forgetLastBackup()
			lastBackupAt = nil
			lastWriteFailed = false
		case .success(.unchanged):
			lastWriteFailed = false
		case .failure(let error):
			lastWriteFailed = true
			// Once per launch: a full disk would otherwise report after every change.
			report(error, operation: "write_backup", once: &hasReportedWriteFailure)
		}
	}

	nonisolated private static func write(
		_ snapshot: LibrarySnapshot, to folder: BackupFolder, lastHash: String?
	) throws -> ICloudBackupWriteOutcome {
		let hash = try BackupCodec.contentHash(of: snapshot.document)
		let exists = folder.hasDocument
		// An unchanged library needs no write, unless the backup is gone, as when deleted from another device, or damaged.
		if hash == lastHash, exists, folder.isIntact { return .unchanged }
		if snapshot.document.isEmpty, !exists { return .skipped }
		try folder.write(snapshot)
		return .written(hash)
	}

	private func report(_ error: Error, operation: String, once reported: inout Bool) {
		guard !reported else { return }
		reported = true
		analytics.report(AnalyticsFailure(operation: operation, error: error))
	}

	func setEnabled(_ enabled: Bool) {
		guard enabled != isEnabled else { return }
		isEnabled = enabled
		settings.isEnabled = enabled
		analytics.track(.iCloudBackupToggled(isOn: enabled))
		if enabled {
			libraryChanged()
		} else {
			passes.cancel()
		}
	}

	/// Checks whether iCloud has the latest backup, a few times while it is still uploading.
	func watchUpload() {
		uploadCheck?.cancel()
		uploadCheck = Task { [weak self] in
			for delay in [0, 5, 20, 60] {
				if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
				guard !Task.isCancelled, let self else { return }
				let generation = storeGeneration
				let state = await readUploadState()
				// A read for the previous account must not replace the new account's state.
				guard !Task.isCancelled, generation == storeGeneration else { return }
				uploadState = state
				if state != .uploading { return }
			}
		}
	}

	private func readUploadState() async -> BackupUploadState? {
		guard let store, settings.lastBackupAt != nil else { return nil }
		let folder = store.folder(for: settings.writerID)
		return await Task.detached(priority: .utility) { folder.uploadState() }.value
	}

	// MARK: - Restoring

	/// The newest backup of another install with people in it, which the empty mosaic offers. An earlier copy stays in
	/// Settings: its install emptied the library on purpose.
	var restoreOffer: BackupCandidate? {
		guard isEnabled, !isRestoreOfferDismissed else { return nil }
		return candidates.first { !$0.isThisDevice && !$0.isPreviousCopy && !$0.isEmpty }
	}

	func dismissRestoreOffer() {
		isRestoreOfferDismissed = true
		settings.isRestoreOfferDismissed = true
	}

	/// Looks for backups in iCloud. After a reinstall iCloud may take a while to list them, so an empty result is not
	/// final; the app looks again when it returns to the foreground.
	func refreshCandidates() async {
		await locateStoreIfNeeded()
		guard let store, !isLoadingCandidates else { return }
		isLoadingCandidates = true
		let generation = storeGeneration
		let known = await discoverFolders()
		let writerID = settings.writerID
		let found = await Task.detached(priority: .userInitiated) { store.candidates(thisInstall: writerID, knownFolders: known) }.value
		isLoadingCandidates = false
		// The account changed meanwhile: these are the previous account's backups; look again.
		guard generation == storeGeneration else {
			await refreshCandidates()
			return
		}
		candidates = found
	}

	/// Loads `candidate` with every photo checked and copied into `stagingDirectory`. When the latest copy can't be
	/// loaded, its complete previous copy joins the list, so the person can restore that instead.
	func loadBackup(_ candidate: BackupCandidate, stagingDirectory: URL) async throws -> LoadedBackup {
		guard let store else { throw CocoaError(.fileReadNoSuchFile) }
		let writerID = settings.writerID
		let result = await Task.detached(priority: .userInitiated) {
			Result { try store.load(candidate, stagingDirectory: stagingDirectory) }
		}.value
		if case .failure = result, !candidate.isPreviousCopy,
			!candidates.contains(where: { $0.folderName == candidate.folderName && $0.isPreviousCopy }),
			let earlier = await Task.detached(
				priority: .userInitiated, operation: { store.previousCandidate(folderName: candidate.folderName, thisInstall: writerID) }
			).value
		{
			candidates.append(earlier)
			candidates.sort { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
		}
		return try result.get()
	}

	/// Removes `candidate` from iCloud: an install's whole backup, or only its earlier copy. Only a backup still listed
	/// goes: one chosen before the iCloud account changed belongs to the previous account, and the same install folder in
	/// the new one is another backup.
	func deleteBackup(_ candidate: BackupCandidate) async throws {
		guard let store, candidates.contains(candidate) else { throw CocoaError(.fileNoSuchFile) }
		try await Task.detached(priority: .userInitiated) { try store.delete(candidate) }.value
		candidates.removeAll { $0.folderName == candidate.folderName && (!candidate.isPreviousCopy || $0.isPreviousCopy) }
		if candidate.isThisDevice, !candidate.isPreviousCopy {
			// The next change writes a whole backup again.
			settings.forgetLastBackup()
			lastBackupAt = nil
			uploadState = nil
		}
	}

	// MARK: - iCloud account

	private func locateStoreIfNeeded() async {
		guard store == nil else { return }
		if let locating { return await locating.value }
		let generation = storeGeneration
		let task = Task {
			let located = await locateStore()
			// An account change while locating started a newer lookup; this result is for the previous account.
			guard generation == storeGeneration else { return }
			if settings.noteAccount(accountIdentity()) { lastBackupAt = nil }
			store = located
			availability = located == nil ? .unavailable : .available
		}
		locating = task
		await task.value
		if locating == task { locating = nil }
	}

	/// Signing out, or into another account, changes what the container holds: write a whole backup again.
	func accountChanged() {
		storeGeneration += 1
		// Nothing reads or writes the previous account's folder while the new one is located; a write already running
		// finishes there and its result is discarded (see `storeGeneration`).
		store = nil
		locating = nil
		passes.cancel()
		settings.forgetLastBackup()
		lastBackupAt = nil
		candidates = []
		uploadState = nil
		availability = .checking
		Task {
			await locateStoreIfNeeded()
			libraryChanged()
		}
	}
}
