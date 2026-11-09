import Core
import XCTest

@testable import GrowingUp

/// The iCloud backup over a folder on the device: no real iCloud is touched.
@MainActor
final class ICloudBackupServiceTests: XCTestCase {
	private var library: BackupLibraryFixture!
	private var store: BackupFolderStore!
	private var defaults: UserDefaults!
	private var suiteName = ""
	private let gateway = PeopleBackupGatewaySpy()
	private let analytics = AnalyticsGatewaySpy()
	private var isLoaded = true
	private var clock = Date(timeIntervalSince1970: 1_000)

	override func setUpWithError() throws {
		library = try BackupLibraryFixture()
		store = BackupFolderStore(root: library.root.appendingPathComponent("iCloud Container/Backups", isDirectory: true), access: .local)
		suiteName = "ICloudBackupServiceTests.\(UUID().uuidString)"
		defaults = UserDefaults(suiteName: suiteName)
		gateway.base = library.gateway
	}

	override func tearDownWithError() throws {
		defaults.removePersistentDomain(forName: suiteName)
		try library.remove()
	}

	private lazy var settings = BackupSettings(defaults: defaults, prefix: "test.")

	private func makeService(debounce: Duration = .seconds(60), store: BackupFolderStore? = nil) async -> ICloudBackupService {
		let located = store ?? self.store
		let service = ICloudBackupService(
			settings: settings, gateway: gateway, analytics: analytics, debounce: debounce, locateStore: { located },
			now: { [unowned self] in
				clock.addTimeInterval(60)
				return clock
			}, appVersion: "3.2 (50)", deviceModel: "iPhone")
		await service.start(isLibraryLoaded: { [unowned self] in isLoaded }).value
		return service
	}

	private var folder: BackupFolder { store.folder(for: settings.writerID) }

	private func addPerson(_ name: String) throws {
		let picture = UUID()
		try library.addPerson(name: name, appPic: picture, files: ["\(picture.uuidString).png": "picture of \(name)"])
	}

	private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
		let deadline = Date().addingTimeInterval(timeout)
		while !condition() {
			guard Date() < deadline else { return XCTFail("Timed out") }
			try await Task.sleep(for: .milliseconds(20))
		}
	}

	func testChangesInQuickSuccessionMakeOneBackup() async throws {
		try addPerson("Mia")
		let service = await makeService(debounce: .milliseconds(200))
		service.libraryChanged()
		service.libraryChanged()
		try await waitUntil { service.lastBackupAt != nil }
		try await Task.sleep(for: .milliseconds(400))
		XCTAssertEqual(gateway.snapshotCount, 1)
		XCTAssertEqual(try folder.document().people.map(\.name), ["Mia"])
		XCTAssertEqual(service.availability, .available)
	}

	func testAChangeDuringAWriteGetsOneMorePass() async throws {
		try addPerson("Mia")
		let service = await makeService()
		gateway.snapshotDelay = .milliseconds(200)
		let first = Task { await service.backUpNow() }
		try await waitUntil { gateway.snapshotCount == 1 }
		try addPerson("Leo")
		async let second: Void = service.backUpNow()
		async let third: Void = service.backUpNow()
		_ = await (first.value, second, third)
		XCTAssertEqual(gateway.snapshotCount, 2, "Calls during a pass share one more pass")
		XCTAssertEqual(try folder.document().people.count, 2)
	}

	func testAnUnchangedLibraryIsNotWrittenAgain() async throws {
		try addPerson("Mia")
		let service = await makeService()
		await service.backUpNow()
		let first = try XCTUnwrap(service.lastBackupAt)
		await service.backUpNow()
		XCTAssertEqual(service.lastBackupAt, first)
		XCTAssertEqual(try folder.document().createdAt, first)
		XCTAssertThrowsError(try folder.document(previous: true), "Nothing was replaced")

		try addPerson("Leo")
		await service.backUpNow()
		XCTAssertGreaterThan(try XCTUnwrap(service.lastBackupAt), first)
		XCTAssertEqual(try folder.document().people.count, 2)
	}

	func testADeletedOrDamagedBackupIsWrittenAgainEvenUnchanged() async throws {
		try addPerson("Mia")
		let service = await makeService()
		await service.backUpNow()
		try FileManager.default.removeItem(at: folder.url)
		await service.backUpNow()
		XCTAssertTrue(folder.isIntact, "A backup deleted from another device comes back")

		let photos = folder.url.appendingPathComponent(BackupFolder.photosFolderName)
		for name in try FileManager.default.contentsOfDirectory(atPath: photos.path) {
			try FileManager.default.removeItem(at: photos.appendingPathComponent(name))
		}
		XCTAssertFalse(folder.isIntact)
		await service.backUpNow()
		XCTAssertTrue(folder.isIntact, "A backup missing a photo is repaired")
	}

	func testNothingIsWrittenBeforeThePeopleLoad() async throws {
		try addPerson("Mia")
		isLoaded = false
		let service = await makeService()
		await service.backUpNow()
		XCTAssertEqual(gateway.snapshotCount, 0)
		XCTAssertFalse(folder.hasDocument)
		XCTAssertNil(service.lastBackupAt)
	}

	func testAFreshInstallWithNobodyWritesNoEmptyBackup() async throws {
		let service = await makeService()
		await service.backUpNow()
		XCTAssertFalse(folder.hasDocument)
		XCTAssertNil(service.lastBackupAt)

		// Once it has a backup, an emptied library is backed up too, keeping the earlier copy.
		try addPerson("Mia")
		await service.backUpNow()
		try library.removePerson(try XCTUnwrap(library.storedPeople().first).id)
		await service.backUpNow()
		XCTAssertEqual(try folder.document().people.count, 0)
		XCTAssertEqual(try folder.document(previous: true).people.count, 1)
	}

	func testAWriteThatBeganBeforeAnAccountChangeIsDiscarded() async throws {
		try addPerson("Mia")
		let service = await makeService()
		gateway.snapshotDelay = .milliseconds(300)
		let write = Task { await service.backUpNow() }
		try await waitUntil { gateway.snapshotCount == 1 }
		service.accountChanged()
		await write.value

		XCTAssertFalse(folder.hasDocument)
		XCTAssertNil(service.lastBackupAt)
		XCTAssertNil(settings.lastContentHash)
		try await waitUntil { service.availability == .available }
	}

	func testTurningTheBackupOffStopsWritesAndIsCounted() async throws {
		try addPerson("Mia")
		let service = await makeService()
		service.setEnabled(false)
		await service.backUpNow()
		XCTAssertFalse(folder.hasDocument)
		XCTAssertFalse(settings.isEnabled)
		XCTAssertNil(service.restoreOffer)

		service.setEnabled(true)
		await service.backUpNow()
		XCTAssertTrue(folder.hasDocument)
		XCTAssertEqual(analytics.events, [.iCloudBackupToggled(isOn: false), .iCloudBackupToggled(isOn: true)])
	}

	func testAFailedReadOrWriteIsReportedOncePerLaunch() async throws {
		try addPerson("Mia")
		let service = await makeService()
		gateway.base = nil
		gateway.snapshotResult = .failure(CocoaError(.fileReadNoPermission))
		await service.backUpNow()
		await service.backUpNow()
		gateway.base = library.gateway
		// A file where the install's folder should be makes every write fail.
		try FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
		try Data("x".utf8).write(to: folder.url)
		await service.backUpNow()
		await service.backUpNow()
		XCTAssertTrue(service.lastWriteFailed)
		XCTAssertEqual(analytics.operations, ["read_backup", "write_backup"])
	}

	func testWithoutICloudTheBackupIsUnavailable() async {
		let service = ICloudBackupService(settings: settings, gateway: gateway, analytics: analytics, locateStore: { nil })
		await service.start(isLibraryLoaded: { true }).value
		XCTAssertEqual(service.availability, .unavailable)
		await service.refreshCandidates()
		XCTAssertTrue(service.candidates.isEmpty)
	}

	func testTheOfferIsAnotherInstallsNewestBackupWithPeopleUntilDismissed() async throws {
		try addPerson("Mia")
		let older = UUID()
		let newer = UUID()
		let snapshot = { (seconds: TimeInterval) in
			try await self.library.gateway.snapshot(createdAt: Date(timeIntervalSince1970: seconds), appVersion: "3.2", deviceModel: "iPhone")
		}
		try store.folder(for: older).write(try await snapshot(1_000))
		try store.folder(for: newer).write(try await snapshot(2_000))
		try library.removePerson(try XCTUnwrap(library.storedPeople().first).id)
		// The newer install emptied its library: its earlier copy stays in Settings, never on the mosaic.
		try store.folder(for: newer).write(try await snapshot(3_000))
		let service = await makeService()
		await service.backUpNow()
		await service.refreshCandidates()

		XCTAssertEqual(service.candidates.count, 3)
		XCTAssertEqual(service.restoreOffer?.folderName, older.uuidString)

		service.dismissRestoreOffer()
		XCTAssertNil(service.restoreOffer)
		XCTAssertTrue(settings.isRestoreOfferDismissed)
	}

	func testICloudThatWasNotReadyAtLaunchIsFoundOnTheNextChange() async throws {
		try addPerson("Mia")
		var isReady = false
		let located = store
		let service = ICloudBackupService(
			settings: settings, gateway: gateway, analytics: analytics, debounce: .milliseconds(10),
			locateStore: { isReady ? located : nil }, appVersion: "3.2 (50)", deviceModel: "iPhone")
		await service.start(isLibraryLoaded: { true }).value
		XCTAssertEqual(service.availability, .unavailable)

		isReady = true
		service.libraryChanged()

		try await waitUntil { service.lastBackupAt != nil }
		XCTAssertEqual(service.availability, .available)
		XCTAssertTrue(folder.isIntact)
	}

	func testABackupChosenBeforeTheAccountChangedIsNotDeleted() async throws {
		try addPerson("Mia")
		let service = await makeService()
		await service.backUpNow()
		await service.refreshCandidates()
		let chosen = try XCTUnwrap(service.candidates.first)
		// The same install folder may exist in the new account: it is another backup.
		service.accountChanged()
		try await waitUntil { service.availability == .available }

		do {
			try await service.deleteBackup(chosen)
			XCTFail("A backup of the previous account is not deleted")
		} catch {}
		XCTAssertTrue(folder.hasDocument)
	}

	func testAScheduledWriteChecksTheUpload() async throws {
		try addPerson("Mia")
		let service = await makeService(debounce: .milliseconds(10))
		service.libraryChanged()
		try await waitUntil { service.lastBackupAt != nil }
		// A folder on the device is no iCloud file; the check after the write says so.
		try await waitUntil { service.uploadState == .notInICloud }
	}

	func testDeletingThisDevicesBackupWritesItAgainOnTheNextChange() async throws {
		try addPerson("Mia")
		let service = await makeService()
		await service.backUpNow()
		await service.refreshCandidates()
		let own = try XCTUnwrap(service.candidates.first)
		XCTAssertTrue(own.isThisDevice)

		try await service.deleteBackup(own)
		XCTAssertTrue(service.candidates.isEmpty)
		XCTAssertNil(service.lastBackupAt)
		XCTAssertNil(settings.lastContentHash)
		await service.backUpNow()
		XCTAssertTrue(folder.isIntact)
	}
}
