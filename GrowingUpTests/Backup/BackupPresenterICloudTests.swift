import Core
import XCTest

@testable import GrowingUp

/// Restoring from the iCloud backup, over a folder on the device that stands for the iCloud container.
@MainActor
final class BackupPresenterICloudTests: XCTestCase {
	private var source: BackupLibraryFixture!
	private var target: BackupLibraryFixture!
	private var store: BackupFolderStore!
	private var defaults: UserDefaults!
	private var suiteName = ""
	private let analytics = AnalyticsGatewaySpy()
	private let otherInstall = UUID()
	private var reloads = 0

	override func setUpWithError() throws {
		source = try BackupLibraryFixture()
		target = try BackupLibraryFixture()
		store = BackupFolderStore(root: source.root.appendingPathComponent("iCloud Container/Backups", isDirectory: true), access: .local)
		suiteName = "BackupPresenterICloudTests.\(UUID().uuidString)"
		defaults = UserDefaults(suiteName: suiteName)
	}

	override func tearDownWithError() throws {
		defaults.removePersistentDomain(forName: suiteName)
		try source.remove()
		try target.remove()
	}

	private var archive: BackupArchive { BackupArchive(directory: target.root.appendingPathComponent("Archives", isDirectory: true)) }

	/// Another install's backup of Mia with her picture, and a presenter over an empty library that found it.
	private func makePresenter() async throws -> (BackupPresenter, BackupCandidate) {
		let picture = UUID()
		try source.addPerson(name: "Mia", appPic: picture, files: ["\(picture.uuidString).png": "picture"])
		try store.folder(for: otherInstall).write(
			try await source.gateway.snapshot(createdAt: Date(timeIntervalSince1970: 1_000), appVersion: "3.2", deviceModel: "iPhone"))
		let located = store
		let iCloud = ICloudBackupService(
			settings: BackupSettings(defaults: defaults, prefix: "test."), gateway: target.gateway, analytics: analytics,
			locateStore: { located })
		let presenter = BackupPresenter(
			gateway: target.gateway, iCloud: iCloud, archive: archive, analytics: analytics, isLibraryLoaded: { true },
			libraryRestored: { [unowned self] in reloads += 1 })
		await presenter.lookForBackupToRestore(libraryIsEmpty: true)
		return (presenter, try XCTUnwrap(presenter.restoreOffer))
	}

	func testTheOfferRestoresAtOnceWithEveryPhoto() async throws {
		let (presenter, offer) = try await makePresenter()
		await presenter.restoreOffered(offer)

		XCTAssertEqual(presenter.alert, .restored(RestoreSummary(peopleAdded: 1, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true)))
		XCTAssertEqual(reloads, 1)
		let restored = try XCTUnwrap(target.storedPeople().first?.appPicId)
		XCTAssertEqual(try target.contents(of: "\(restored.uuidString).png"), "picture")
		XCTAssertEqual(
			analytics.events,
			[.dataRestored(source: .icloud, peopleAdded: 1, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true)])
		XCTAssertFalse(FileManager.default.fileExists(atPath: archive.directory.appendingPathComponent("Import").path), "The staged photos go")
		XCTAssertNil(presenter.loadingCandidateID)
	}

	func testABackupFromTheListAsksToConfirmFirst() async throws {
		let (presenter, offer) = try await makePresenter()
		await presenter.open(offer)
		XCTAssertEqual(presenter.pendingRestore?.source, .icloud)
		XCTAssertEqual(presenter.pendingRestore?.peopleCount, 1)
		XCTAssertTrue(try target.storedPeople().isEmpty)
	}

	func testAPhotoThatCannotBeReadFailsTheRestoreAsOneToTryAgain() async throws {
		let (presenter, offer) = try await makePresenter()
		let photos = store.folder(for: otherInstall).url.appendingPathComponent(BackupFolder.photosFolderName)
		for name in try FileManager.default.contentsOfDirectory(atPath: photos.path) {
			try Data("not yet".utf8).write(to: photos.appendingPathComponent(name))
		}

		await presenter.restoreOffered(offer)

		XCTAssertEqual(presenter.alert, .iCloudUnreadable(.photoUnavailable))
		XCTAssertEqual(presenter.alert?.message, "Couldn't read the backup. Check your internet connection and try again.")
		XCTAssertTrue(try target.storedPeople().isEmpty, "Nobody is restored without their photo")
		XCTAssertNil(presenter.pendingRestore)
		XCTAssertTrue(analytics.failures.isEmpty)
		XCTAssertNotNil(presenter.restoreOffer, "The offer stays to try again")
	}

	func testDeletingABackupRemovesItFromTheList() async throws {
		let (presenter, offer) = try await makePresenter()
		await presenter.delete(offer)
		XCTAssertNil(presenter.restoreOffer)
		XCTAssertTrue(presenter.iCloud?.candidates.isEmpty == true)
		XCTAssertFalse(FileManager.default.fileExists(atPath: store.folder(for: otherInstall).url.path))
	}

	func testNoOfferIsLookedForNextToPeople() async throws {
		let (presenter, _) = try await makePresenter()
		let other = ICloudBackupService(
			settings: BackupSettings(defaults: defaults, prefix: "other."), gateway: target.gateway, analytics: analytics,
			locateStore: { [store] in store })
		let next = BackupPresenter(gateway: target.gateway, iCloud: other, analytics: analytics, isLibraryLoaded: { true }, libraryRestored: {})
		await next.lookForBackupToRestore(libraryIsEmpty: false)
		XCTAssertNil(next.restoreOffer)
		XCTAssertNotNil(presenter.restoreOffer)
	}
}
