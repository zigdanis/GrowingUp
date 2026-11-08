import CoreData
import XCTest

@testable import Core

final class PreservedStoreLibraryTests: XCTestCase {
	private var root: URL!
	/// A space in the path, as in the App Group's `Application Support`, catches percent-encoded lookups.
	private var storeFolder: URL { root.appendingPathComponent("Application Support", isDirectory: true) }
	private var store: URL { storeFolder.appendingPathComponent("GrowingUp.sqlite") }
	private var exports: URL { root.appendingPathComponent("Exports", isDirectory: true) }
	private var library: PreservedStoreLibrary {
		PreservedStoreLibrary(storeURL: store, photosDirectory: root, exportsDirectory: exports)
	}

	override func setUpWithError() throws {
		root = FileManager.default.temporaryDirectory.appendingPathComponent("Preserved \(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: storeFolder, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: root)
	}

	func testNoFolderOrNoBackupsMeansNothingPreserved() throws {
		XCTAssertEqual(try library.stores(), [])
		let missing = PreservedStoreLibrary(
			storeURL: root.appendingPathComponent("Missing/GrowingUp.sqlite"), photosDirectory: root, exportsDirectory: exports)
		XCTAssertEqual(try missing.stores(), [])
	}

	func testRecoveryNotesItsCauseAndTheStoreIsListedAfterRelaunch() throws {
		try writeFamily()
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let backup = try SQLiteStoreBackup().moveStore(
			at: store, cause: .incompatibleModel(code: NSPersistentStoreIncompatibleVersionHashError), date: date)
		// A new library value reads only what is on disk, as a relaunch does.
		let stores = try library.stores()
		XCTAssertEqual(stores.map(\.id), [backup.lastPathComponent])
		XCTAssertEqual(stores[0].preservedAt, date)
		XCTAssertEqual(stores[0].cause, .incompatibleModel(code: NSPersistentStoreIncompatibleVersionHashError))
		XCTAssertFalse(stores[0].hasPreservedPhotos)
		XCTAssertFalse(stores[0].isReported)
		let manifest = try XCTUnwrap(PreservedStoreManifest.read(in: backup))
		XCTAssertEqual(manifest.process, "app")
	}

	func testStoreRecoveryThroughTheStackIsListedWithItsCause() throws {
		try writeFamily()
		var attempts = 0
		let stack = CoreDataStackImplementation(makeContainer: makeContainer) { candidate in
			attempts += 1
			if attempts == 1 { throw NSError(domain: NSCocoaErrorDomain, code: NSMigrationMissingSourceModelError) }
			try CoreDataStackImplementation.loadPersistentStores(candidate)
		}
		let container = try stack.persistentContainer
		defer { container.persistentStoreCoordinator.persistentStores.forEach { try? container.persistentStoreCoordinator.remove($0) } }
		XCTAssertEqual(try library.stores().map(\.cause), [.incompatibleModel(code: NSMigrationMissingSourceModelError)])
	}

	func testFolderFromAnEarlierVersionIsListedWithTheDateInItsName() throws {
		let folder = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-\(UUID().uuidString)")
		let stores = try library.stores()
		XCTAssertEqual(stores.map(\.id), [folder.lastPathComponent])
		XCTAssertEqual(stores[0].cause, .unknown)
		XCTAssertEqual(stores[0].preservedAt, ISO8601DateFormatter().date(from: "2026-10-21T08:15:30Z"))
		XCTAssertNil(try PreservedStoreManifest.read(in: folder), "Listing writes nothing")
	}

	func testNewestFirstAndFoldersWithoutAStoreOrStillMovingAreLeftOut() throws {
		let older = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-01-01T00-00-00Z-A")
		let newer = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-06-01T00-00-00Z-B")
		// A rolled back move leaves only its note.
		let empty = storeFolder.appendingPathComponent("GrowingUp.sqlite.backup-2026-07-01T00-00-00Z-C", isDirectory: true)
		try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: false)
		try PreservedStoreManifest(preservedAt: Date(), cause: .unknown).write(in: empty)
		let moving = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-08-01T00-00-00Z-D")
		try Data(moving.lastPathComponent.utf8).write(to: store.appendingPathExtension("recovery"))
		XCTAssertEqual(try library.stores().map(\.id), [newer.lastPathComponent, older.lastPathComponent])
	}

	func testInterruptedMoveFromAnEarlierVersionIsNotedAsInterrupted() throws {
		try writeFamily()
		let backup = storeFolder.appendingPathComponent("GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-X", isDirectory: true)
		try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
		try Data(backup.lastPathComponent.utf8).write(to: store.appendingPathExtension("recovery"))
		try FileManager.default.moveItem(at: URL(fileURLWithPath: store.path + "-wal"), to: backup.appendingPathComponent("GrowingUp.sqlite-wal"))
		XCTAssertEqual(try library.stores(), [], "Unfinished until a store load resumes it")
		XCTAssertEqual(try SQLiteStoreBackup().resumePendingMove(at: store), backup)
		XCTAssertEqual(try library.stores().map(\.cause), [.interrupted])
	}

	func testInterruptedMoveKeepsTheCauseNotedBeforeIt() throws {
		try writeFamily()
		let mover = SQLiteStoreBackup { source, destination in
			// The process "dies" after the WAL moved: the journal stays.
			if !source.lastPathComponent.hasSuffix("-wal") { throw CocoaError(.fileWriteUnknown) }
			try FileManager.default.moveItem(at: source, to: destination)
		}
		let failingRollback = SQLiteStoreBackup { source, destination in
			if source.deletingLastPathComponent() != self.storeFolder { throw CocoaError(.fileWriteUnknown) }
			try mover.moveItem(source, destination)
		}
		XCTAssertThrowsError(try failingRollback.moveStore(at: store, cause: .incompatibleModel(code: 134_100)))
		XCTAssertNotNil(try SQLiteStoreBackup().resumePendingMove(at: store))
		XCTAssertEqual(try library.stores().map(\.cause), [.incompatibleModel(code: 134_100)])
	}

	func testPhotosOfAnEarlierVersionsStoreAreKeptOnceAndOutliveTheirLooseFiles() throws {
		let folder = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-P")
		let old = UUID()
		try Data("old picture".utf8).write(to: root.appendingPathComponent("\(old.uuidString).png"))
		try Data("old original".utf8).write(to: root.appendingPathComponent("\(old.uuidString).heic"))
		try Data("not a photo".utf8).write(to: root.appendingPathComponent("notes.png"))
		let kept = try library.preservePhotos(of: try XCTUnwrap(library.stores().first))
		XCTAssertTrue(kept.hasPreservedPhotos)
		let photos = folder.appendingPathComponent("Photos")
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: photos.path).sorted(), ["\(old.uuidString).heic", "\(old.uuidString).png"])
		XCTAssertEqual(try PreservedStoreManifest.read(in: folder)?.cause, "unknown")
		// A photo added later belongs to the active library, and a person removed from it takes only the loose file.
		try Data("later".utf8).write(to: root.appendingPathComponent("\(UUID().uuidString).png"))
		try FileManager.default.removeItem(at: root.appendingPathComponent("\(old.uuidString).png"))
		XCTAssertEqual(try library.preservePhotos(of: kept), kept)
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: photos.path).count, 2)
		XCTAssertEqual(try Data(contentsOf: photos.appendingPathComponent("\(old.uuidString).png")), Data("old picture".utf8))
	}

	func testRecoveryKeepsThePhotosAsItSetsTheStoreAside() throws {
		try writeFamily()
		let photo = UUID()
		try Data("photo".utf8).write(to: root.appendingPathComponent("\(photo.uuidString).heic"))
		var attempts = 0
		let stack = CoreDataStackImplementation(makeContainer: makeContainer, photosDirectory: root) { candidate in
			attempts += 1
			if attempts == 1 { throw NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError) }
			try CoreDataStackImplementation.loadPersistentStores(candidate)
		}
		let container = try stack.persistentContainer
		defer { container.persistentStoreCoordinator.persistentStores.forEach { try? container.persistentStoreCoordinator.remove($0) } }
		let preserved = try XCTUnwrap(library.stores().first)
		XCTAssertTrue(preserved.hasPreservedPhotos, "Kept before the app, which may hold the old people in memory, refreshes")
		let folder = storeFolder.appendingPathComponent(preserved.id)
		XCTAssertEqual(try PreservedStoreManifest.read(in: folder)?.photoFileNames, ["\(photo.uuidString).heic"])
		try FileManager.default.removeItem(at: root.appendingPathComponent("\(photo.uuidString).heic"))
		XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("Photos/\(photo.uuidString).heic")), Data("photo".utf8))
	}

	func testExportOfAnInterruptedPhotoPassIncludesTheLinkedAndTheLoosePhotos() throws {
		let folder = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-I")
		let linked = UUID()
		let loose = UUID()
		let photos = folder.appendingPathComponent("Photos")
		try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
		// The pass linked one photo, then stopped; its loose source has gone since.
		try Data("linked".utf8).write(to: photos.appendingPathComponent("\(linked.uuidString).png"))
		try Data("loose".utf8).write(to: root.appendingPathComponent("\(loose.uuidString).png"))
		let preserved = try XCTUnwrap(library.stores().first)
		XCTAssertFalse(preserved.hasPreservedPhotos)
		XCTAssertEqual(
			try library.exportedPhotos(in: folder).map(\.lastPathComponent), ["\(linked.uuidString).png", "\(loose.uuidString).png"].sorted())
		let rescued = try XCTUnwrap(library.exportedPhotos(in: folder).first { $0.lastPathComponent.hasPrefix(linked.uuidString) })
		XCTAssertEqual(try Data(contentsOf: rescued), Data("linked".utf8))
		XCTAssertNoThrow(try library.export(preserved, now: Date()))
		// Once the pass is done, only what it kept counts.
		_ = try library.preservePhotos(of: preserved)
		try Data("later".utf8).write(to: root.appendingPathComponent("\(UUID().uuidString).png"))
		XCTAssertEqual(try library.exportedPhotos(in: folder).count, 2)
	}

	func testRecoveryIsReportedOnce() throws {
		_ = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-S")
		let reported = try library.markReported(try XCTUnwrap(library.stores().first))
		XCTAssertTrue(reported.isReported)
		XCTAssertTrue(try XCTUnwrap(library.stores().first).isReported)
		XCTAssertEqual(try library.markReported(reported), reported)
	}

	func testExportIsOneArchiveAndLeavesThePreservedFilesAsTheyWere() throws {
		try writeFamily()
		let backup = try SQLiteStoreBackup().moveStore(at: store, cause: .incompatibleModel(code: 134_100), date: Date(timeIntervalSince1970: 0))
		let photo = UUID()
		try Data("photo".utf8).write(to: root.appendingPathComponent("\(photo.uuidString).png"))
		let kept = try library.preservePhotos(of: try XCTUnwrap(library.stores().first))
		let before = try digests(in: backup)
		let archive = try library.export(kept, now: Date(timeIntervalSince1970: 60))
		XCTAssertEqual(archive.lastPathComponent, "GrowingUp-earlier-data-1970-01-01.zip")
		XCTAssertEqual(try Data(contentsOf: archive).prefix(2), Data("PK".utf8))
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: exports.path), [archive.lastPathComponent], "Staging is removed")
		XCTAssertEqual(try digests(in: backup), before)
		XCTAssertEqual(try library.stores(), [kept])
		library.removeExports()
		XCTAssertFalse(FileManager.default.fileExists(atPath: exports.path))
	}

	func testStagedArchiveListsEveryFileWithItsChecksum() throws {
		try writeFamily()
		let backup = try SQLiteStoreBackup().moveStore(at: store, date: Date(timeIntervalSince1970: 0))
		let photo = root.appendingPathComponent("\(UUID().uuidString).heic")
		try Data("photo".utf8).write(to: photo)
		let preserved = try XCTUnwrap(library.stores().first)
		try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
		let staged = try PreservedStoreArchiver(storeFileName: "GrowingUp.sqlite").stage(
			store: preserved, folder: backup, photos: [photo], exportedAt: Date(timeIntervalSince1970: 60), in: exports)
		let data = try Data(contentsOf: staged.appendingPathComponent("manifest.json"))
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let manifest = try decoder.decode(ArchiveManifest.self, from: data)
		XCTAssertEqual(manifest.preservedAt, Date(timeIntervalSince1970: 0))
		XCTAssertEqual(manifest.cause, 0)
		XCTAssertEqual(
			manifest.files.map(\.path),
			["Store/GrowingUp.sqlite", "Store/GrowingUp.sqlite-wal", "Store/GrowingUp.sqlite-shm", "Photos/\(photo.lastPathComponent)"])
		for file in manifest.files {
			let url = staged.appendingPathComponent(file.path)
			XCTAssertEqual(file.sha256, try ArchivedFile.digest(of: url))
			XCTAssertEqual(file.size, try Data(contentsOf: url).count)
		}
		XCTAssertEqual(manifest.files[0].sha256, try ArchivedFile.digest(of: backup.appendingPathComponent("GrowingUp.sqlite")))
		XCTAssertTrue(FileManager.default.fileExists(atPath: staged.appendingPathComponent("README.txt").path))
	}

	func testFailedExportLeavesNoArchiveAndKeepsThePreservedStore() throws {
		try writeFamily()
		let backup = try SQLiteStoreBackup().moveStore(at: store, date: Date(timeIntervalSince1970: 0))
		let preserved = try XCTUnwrap(library.stores().first)
		let before = try digests(in: backup)
		// A photo that vanishes between listing and staging fails the export.
		let missing = root.appendingPathComponent("\(UUID().uuidString).png")
		try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
		XCTAssertThrowsError(
			try PreservedStoreArchiver(storeFileName: "GrowingUp.sqlite").stage(
				store: preserved, folder: backup, photos: [missing], exportedAt: Date(), in: exports))
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: exports.path), [])
		XCTAssertEqual(try digests(in: backup), before)
		// A retry once the cause is gone succeeds.
		XCTAssertNoThrow(try library.export(preserved, now: Date()))
	}

	func testDeletingRemovesOnlyTheFolderAndKeepsEveryLoosePhoto() throws {
		let folder = try legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-D")
		let photo = root.appendingPathComponent("\(UUID().uuidString).png")
		try Data("photo".utf8).write(to: photo)
		let kept = try library.preservePhotos(of: try XCTUnwrap(library.stores().first))
		XCTAssertGreaterThan(kept.byteCount, 0)
		try library.delete(kept)
		XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
		XCTAssertEqual(try Data(contentsOf: photo), Data("photo".utf8))
		XCTAssertEqual(try library.stores(), [])
		XCTAssertTrue(FileManager.default.fileExists(atPath: storeFolder.path), "The active store's folder stays")
		let outside = PreservedStore(
			id: "../Elsewhere", preservedAt: Date(), cause: .unknown, appVersion: nil, hasPreservedPhotos: false, isReported: false)
		XCTAssertThrowsError(try library.delete(outside))
	}

	func testPhotoFileNames() {
		let id = UUID()
		XCTAssertEqual(PhotoFileName.id(of: "\(id.uuidString).png"), id)
		XCTAssertEqual(PhotoFileName.id(of: "\(id.uuidString).HEIC"), id)
		XCTAssertEqual(PhotoFileName.id(of: "\(id.uuidString).jpg"), id)
		XCTAssertNil(PhotoFileName.id(of: "\(id.uuidString).sqlite"))
		XCTAssertNil(PhotoFileName.id(of: "cover.png"))
	}

	private func writeFamily() throws {
		for suffix in ["", "-wal", "-shm"] {
			try Data("saved\(suffix)".utf8).write(to: URL(fileURLWithPath: store.path + suffix))
		}
	}

	private func legacyFolder(named name: String) throws -> URL {
		let folder = storeFolder.appendingPathComponent(name, isDirectory: true)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
		try Data("old people".utf8).write(to: folder.appendingPathComponent("GrowingUp.sqlite"))
		return folder
	}

	private func digests(in folder: URL) throws -> [String: String] {
		var digests: [String: String] = [:]
		for name in ["GrowingUp.sqlite", "GrowingUp.sqlite-wal", "GrowingUp.sqlite-shm"] {
			let url = folder.appendingPathComponent(name)
			if FileManager.default.fileExists(atPath: url.path) { digests[name] = try ArchivedFile.digest(of: url) }
		}
		return digests
	}

	private func makeContainer() throws -> NSPersistentContainer {
		let modelURL = try XCTUnwrap(Bundle(for: CoreDataPerson.self).url(forResource: "GrowingUp", withExtension: "momd"))
		let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: store)]
		return container
	}
}
