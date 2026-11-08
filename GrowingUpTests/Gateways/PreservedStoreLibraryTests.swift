import CoreData
import XCTest

@testable import Core

final class PreservedStoreLibraryTests: XCTestCase {
	private var fixture: PreservedStoreFixture!
	private var root: URL { fixture.root }
	private var storeFolder: URL { fixture.storeFolder }
	private var store: URL { fixture.store }
	private var exports: URL { fixture.exports }
	private var library: PreservedStoreLibrary { fixture.library }

	override func setUpWithError() throws {
		fixture = try PreservedStoreFixture()
	}

	override func tearDownWithError() throws {
		try fixture.remove()
	}

	func testNoFolderOrNoBackupsMeansNothingPreserved() throws {
		XCTAssertEqual(try library.stores(), [])
		let missing = PreservedStoreLibrary(
			storeURL: root.appendingPathComponent("Missing/GrowingUp.sqlite"), photosDirectory: root, exportsDirectory: exports)
		XCTAssertEqual(try missing.stores(), [])
	}

	func testRecoveryNotesItsCauseAndTheStoreIsListedAfterRelaunch() throws {
		try fixture.writeFamily()
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
		try fixture.writeFamily()
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
		let folder = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-\(UUID().uuidString)")
		let stores = try library.stores()
		XCTAssertEqual(stores.map(\.id), [folder.lastPathComponent])
		XCTAssertEqual(stores[0].cause, .unknown)
		XCTAssertEqual(stores[0].preservedAt, ISO8601DateFormatter().date(from: "2026-10-21T08:15:30Z"))
		XCTAssertNil(try PreservedStoreManifest.read(in: folder), "Listing writes nothing")
	}

	func testNewestFirstAndFoldersWithoutAStoreOrStillMovingAreLeftOut() throws {
		let older = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-01-01T00-00-00Z-A")
		let newer = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-06-01T00-00-00Z-B")
		// A rolled back move leaves only its note.
		let empty = storeFolder.appendingPathComponent("GrowingUp.sqlite.backup-2026-07-01T00-00-00Z-C", isDirectory: true)
		try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: false)
		try PreservedStoreManifest(preservedAt: Date(), cause: .unknown).write(in: empty)
		let moving = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-08-01T00-00-00Z-D")
		try Data(moving.lastPathComponent.utf8).write(to: store.appendingPathExtension("recovery"))
		XCTAssertEqual(try library.stores().map(\.id), [newer.lastPathComponent, older.lastPathComponent])
	}

	func testInterruptedMoveFromAnEarlierVersionIsNotedAsInterrupted() throws {
		try fixture.writeFamily()
		let backup = storeFolder.appendingPathComponent("GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-X", isDirectory: true)
		try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
		try Data(backup.lastPathComponent.utf8).write(to: store.appendingPathExtension("recovery"))
		try FileManager.default.moveItem(at: URL(fileURLWithPath: store.path + "-wal"), to: backup.appendingPathComponent("GrowingUp.sqlite-wal"))
		XCTAssertEqual(try library.stores(), [], "Unfinished until a store load resumes it")
		XCTAssertEqual(try SQLiteStoreBackup().resumePendingMove(at: store), backup)
		XCTAssertEqual(try library.stores().map(\.cause), [.interrupted])
	}

	func testInterruptedMoveKeepsTheCauseNotedBeforeIt() throws {
		try fixture.writeFamily()
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
		let folder = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-P")
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
		try fixture.writeFamily()
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

	func testRecoveryIsReportedOnce() throws {
		_ = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-S")
		let reported = try library.markReported(try XCTUnwrap(library.stores().first))
		XCTAssertTrue(reported.isReported)
		XCTAssertTrue(try XCTUnwrap(library.stores().first).isReported)
		XCTAssertEqual(try library.markReported(reported), reported)
	}

	func testDeletingRemovesOnlyTheFolderAndKeepsEveryLoosePhoto() throws {
		let folder = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-D")
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

	func testAnUnreadableNoteIsKeptAsideRatherThanOverwritten() throws {
		let folder = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-U")
		try Data("{ not json".utf8).write(to: folder.appendingPathComponent("Preserved.json"))
		let listed = try XCTUnwrap(library.stores().first, "An unreadable note still shows the store")
		XCTAssertEqual(listed.cause, .unknown)
		_ = try library.preservePhotos(of: listed)
		let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("Preserved-unreadable-") }
		XCTAssertEqual(kept.count, 1)
		XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(kept[0])), Data("{ not json".utf8))
		XCTAssertNotNil(try PreservedStoreManifest.read(in: folder))
	}

	func testAStoreARecoveryJournalNamesCannotBeDeleted() throws {
		let folder = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-J")
		let listed = try XCTUnwrap(library.stores().first)
		try Data(folder.lastPathComponent.utf8).write(to: store.appendingPathExtension("recovery"))
		XCTAssertThrowsError(try library.delete(listed))
		XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("GrowingUp.sqlite").path))
	}

	private func makeContainer() throws -> NSPersistentContainer {
		let modelURL = try XCTUnwrap(Bundle(for: CoreDataPerson.self).url(forResource: "GrowingUp", withExtension: "momd"))
		let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: store)]
		return container
	}
}
