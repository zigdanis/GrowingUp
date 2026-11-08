import Core
import XCTest

@testable import GrowingUp

@MainActor
final class BackupPresenterTests: XCTestCase {
	private var directory: URL!
	private let gateway = PeopleBackupGatewaySpy()
	private let analytics = AnalyticsGatewaySpy()
	private var isLoaded = true
	private var reloads = 0

	override func setUpWithError() throws {
		directory = FileManager.default.temporaryDirectory.appendingPathComponent("Backup Presenter \(UUID().uuidString)", isDirectory: true)
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: directory)
	}

	private func makePresenter() -> BackupPresenter {
		BackupPresenter(
			gateway: gateway, archive: BackupArchive(directory: directory), analytics: analytics,
			isLibraryLoaded: { [unowned self] in isLoaded }, libraryRestored: { [unowned self] in reloads += 1 })
	}

	private func pending() -> PendingRestore {
		let document = BackupDocument(createdAt: Date(), appVersion: "1", deviceModel: "iPhone", people: [], photos: [])
		return PendingRestore(backup: LoadedBackup(document: document, photoFiles: [:]), source: .file)
	}

	func testAnExportIsReadyToShareAndCountsOnlyPeople() async throws {
		let presenter = makePresenter()
		await presenter.startExport()
		guard case .ready(let url) = presenter.export else { return XCTFail("The export is ready") }
		XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
		XCTAssertEqual(analytics.events, [.dataExported(peopleCount: 0)])
		presenter.finishExport()
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "The file goes once the share sheet closes")
	}

	func testAFailedExportExplainsItselfAndIsReported() async {
		gateway.snapshotResult = .failure(CocoaError(.fileReadNoPermission))
		let presenter = makePresenter()
		await presenter.startExport()
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertEqual(presenter.alert, .exportFailed)
		XCTAssertEqual(analytics.operations, ["export_data"])
	}

	func testNothingIsExportedOrRestoredBeforeThePeopleLoad() async {
		isLoaded = false
		let presenter = makePresenter()
		XCTAssertFalse(presenter.isAvailable)
		await presenter.startExport()
		XCTAssertEqual(presenter.export, .idle)
		await presenter.confirmRestore(pending())?.value
		XCTAssertEqual(presenter.alert, .restoreFailed)
		XCTAssertEqual(gateway.restored.count, 0)
	}

	func testAConfirmedRestoreShowsWhatItAddedAndReloadsThePeople() async {
		let presenter = makePresenter()
		let restore = pending()
		presenter.pendingRestore = restore
		await presenter.confirmRestore(restore)?.value
		XCTAssertNil(presenter.pendingRestore)
		XCTAssertEqual(gateway.restored.count, 1)
		XCTAssertEqual(reloads, 1)
		XCTAssertEqual(presenter.alert, .restored(RestoreSummary(peopleAdded: 1, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true)))
		XCTAssertEqual(
			analytics.events,
			[.dataRestored(source: .file, peopleAdded: 1, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true)])
	}

	func testAFailedRestoreChangesNothingAndIsReported() async {
		gateway.restoreResult = .failure(CocoaError(.fileWriteOutOfSpace))
		let presenter = makePresenter()
		await presenter.confirmRestore(pending())?.value
		XCTAssertEqual(presenter.alert, .restoreFailed)
		XCTAssertEqual(reloads, 0)
		XCTAssertEqual(analytics.operations, ["restore_backup"])
	}

	func testAPickedFileThatIsNoBackupIsExplainedButNotReported() async throws {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		let file = directory.appendingPathComponent("photo.zip")
		try Data("not a zip".utf8).write(to: file)
		let presenter = makePresenter()
		await presenter.open(pickedFile: file)
		XCTAssertNil(presenter.pendingRestore)
		XCTAssertEqual(presenter.alert, .unreadable(.notABackup))
		XCTAssertEqual(analytics.failures.count, 0)
	}

	func testTheConfirmationClosingBeforeItsButtonRunsStillRestoresEveryPhoto() async throws {
		let source = try BackupLibraryFixture()
		let target = try BackupLibraryFixture()
		defer {
			try? source.remove()
			try? target.remove()
		}
		let picture = UUID()
		try source.addPerson(name: "Mia", appPic: picture, files: ["\(picture.uuidString).png": "picture"])
		let zip = try BackupArchive(directory: source.root.appendingPathComponent("Out"))
			.export(try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone"))
		let presenter = BackupPresenter(
			gateway: target.gateway, archive: BackupArchive(directory: directory), analytics: analytics, isLibraryLoaded: { true },
			libraryRestored: {})
		await presenter.open(pickedFile: zip)
		let pending = try XCTUnwrap(presenter.pendingRestore)
		// SwiftUI may reset the dialog's binding before it runs the chosen button.
		presenter.dismissRestoreConfirmation()
		await presenter.confirmRestore(pending)?.value
		XCTAssertEqual(presenter.alert, .restored(RestoreSummary(peopleAdded: 1, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true)))
		let restored = try XCTUnwrap(target.storedPeople().first?.appPicId)
		XCTAssertEqual(try target.contents(of: "\(restored.uuidString).png"), "picture")
	}

	func testAFileStillBeingReadWhenTheSheetClosesIsNeverOffered() async throws {
		let source = try BackupLibraryFixture()
		defer { try? source.remove() }
		try source.addPerson(name: "Mia")
		let zip = try BackupArchive(directory: source.root.appendingPathComponent("Out"))
			.export(try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone"))
		let presenter = makePresenter()
		let reading = Task { await presenter.open(pickedFile: zip) }
		while !presenter.isReading { await Task.yield() }
		presenter.abandon()
		await reading.value
		XCTAssertNil(presenter.pendingRestore)
		XCTAssertNil(presenter.alert)
		XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Import").path))
	}

	func testTheRestoreAlertSaysWhoDidNotFit() {
		let summary = RestoreSummary(peopleAdded: 0, peopleAlreadyPresent: 3, peopleOverLimit: 2, intoEmptyLibrary: false)
		let message = BackupAlert.restored(summary).message
		XCTAssertTrue(message.contains("already"), message)
		XCTAssertTrue(message.contains("2"), message)
	}
}
