import CoreData
import XCTest

@testable import Core

final class CoreDataStackImplementationTests: XCTestCase {
	private var directory: URL!
	private var store: URL { directory.appendingPathComponent("GrowingUp.sqlite") }

	override func setUpWithError() throws {
		directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: directory)
	}

	func testIncompatibleStoreIsPreservedAndReturnedContainerLoadsFreshStore() throws {
		for suffix in ["", "-wal", "-shm"] {
			try Data("saved\(suffix)".utf8).write(to: URL(fileURLWithPath: store.path + suffix))
		}
		let container = try makeContainer()
		var attempts = 0
		let stack = CoreDataStackImplementation(makeContainer: { container }) { candidate in
			attempts += 1
			XCTAssertTrue(candidate === container)
			if attempts == 1 {
				throw NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError)
			}
			try CoreDataStackImplementation.loadPersistentStores(candidate)
		}
		let returned = try stack.persistentContainer
		defer { close(returned) }
		XCTAssertTrue(returned === container)
		XCTAssertEqual(returned.persistentStoreCoordinator.persistentStores.count, 1)
		XCTAssertTrue(try stack.persistentContainer === returned)
		XCTAssertEqual(attempts, 2)
		let backup = try XCTUnwrap(
			FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
				.first { $0.lastPathComponent.contains(".backup-") })
		for suffix in ["", "-wal", "-shm"] {
			XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent(store.lastPathComponent + suffix)), Data("saved\(suffix)".utf8))
		}
		try returned.viewContext.performAndWait {
			XCTAssertEqual(try returned.viewContext.count(for: CoreDataPerson.fetchRequest()), 0)
		}
	}

	func testNonModelLoadFailuresReachCallerWithoutChangingAnyFiles() throws {
		try Data("people".utf8).write(to: store)
		for suffix in ["-wal", "-shm"] {
			try Data(suffix.utf8).write(to: URL(fileURLWithPath: store.path + suffix))
		}
		for code in [NSFileReadNoPermissionError, NSFileWriteNoPermissionError, NSPersistentStoreOpenError, NSMigrationError] {
			let expected = NSError(domain: NSCocoaErrorDomain, code: code)
			var attempts = 0
			let stack = CoreDataStackImplementation(makeContainer: self.makeContainer) { _ in
				attempts += 1
				throw expected
			}
			XCTAssertThrowsError(try stack.persistentContainer) { XCTAssertEqual($0 as NSError, expected) }
			XCTAssertEqual(attempts, 1)
			XCTAssertEqual(
				try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(),
				["GrowingUp.sqlite", "GrowingUp.sqlite-shm", "GrowingUp.sqlite-wal"])
			XCTAssertEqual(try Data(contentsOf: store), Data("people".utf8))
			for suffix in ["-wal", "-shm"] {
				XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: store.path + suffix)), Data(suffix.utf8))
			}
		}
	}

	func testTransientFailureCanBeRetriedAndMigrationIsExplicitlyEnabled() throws {
		let container = try makeContainer()
		let description = try XCTUnwrap(container.persistentStoreDescriptions.first)
		description.shouldMigrateStoreAutomatically = false
		description.shouldInferMappingModelAutomatically = false
		var attempts = 0
		let stack = CoreDataStackImplementation(makeContainer: { container }) { candidate in
			attempts += 1
			if attempts == 1 { throw CocoaError(.fileReadNoPermission) }
			try CoreDataStackImplementation.loadPersistentStores(candidate)
		}
		XCTAssertThrowsError(try stack.persistentContainer)
		let returned = try stack.persistentContainer
		defer { close(returned) }
		XCTAssertTrue(description.shouldMigrateStoreAutomatically)
		XCTAssertTrue(description.shouldInferMappingModelAutomatically)
		XCTAssertFalse(description.shouldAddStoreAsynchronously)
		XCTAssertEqual(attempts, 2)
	}

	func testFailedFreshLoadThrowsAfterOneRetryAndKeepsBackup() throws {
		try Data("people".utf8).write(to: store)
		var attempts = 0
		let stack = CoreDataStackImplementation(makeContainer: self.makeContainer) { _ in
			attempts += 1
			throw NSError(domain: NSCocoaErrorDomain, code: NSMigrationMissingSourceModelError)
		}
		XCTAssertThrowsError(try stack.persistentContainer)
		XCTAssertEqual(attempts, 2)
		let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
		XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent(store.lastPathComponent)), Data("people".utf8))
	}

	func testBackupFailureDoesNotAttemptFreshLoad() throws {
		var attempts = 0
		let stack = CoreDataStackImplementation(makeContainer: self.makeContainer) { _ in
			attempts += 1
			throw NSError(domain: NSCocoaErrorDomain, code: NSMigrationMissingSourceModelError)
		}
		XCTAssertThrowsError(try stack.persistentContainer)
		XCTAssertEqual(attempts, 1)
		XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
	}

	func testPendingRecoveryCompletesBeforeFirstLoad() throws {
		let backup = directory.appendingPathComponent("GrowingUp.sqlite.backup-interrupted", isDirectory: true)
		try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
		try Data("people".utf8).write(to: store)
		try Data("committed WAL".utf8).write(to: backup.appendingPathComponent("GrowingUp.sqlite-wal"))
		try Data(backup.lastPathComponent.utf8).write(to: store.appendingPathExtension("recovery"), options: .atomic)
		var attempts = 0
		let stack = CoreDataStackImplementation(makeContainer: self.makeContainer) { candidate in
			attempts += 1
			XCTAssertFalse(FileManager.default.fileExists(atPath: self.store.path))
			XCTAssertFalse(FileManager.default.fileExists(atPath: self.store.appendingPathExtension("recovery").path))
			XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("GrowingUp.sqlite")), Data("people".utf8))
			XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("GrowingUp.sqlite-wal")), Data("committed WAL".utf8))
			try CoreDataStackImplementation.loadPersistentStores(candidate)
		}
		let returned = try stack.persistentContainer
		defer { close(returned) }
		XCTAssertEqual(attempts, 1)
		XCTAssertEqual(returned.persistentStoreCoordinator.persistentStores.count, 1)
	}

	private func makeContainer() throws -> NSPersistentContainer {
		let modelURL = try XCTUnwrap(Bundle(for: CoreDataPerson.self).url(forResource: "GrowingUp", withExtension: "momd"))
		let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: store)]
		return container
	}

	private func close(_ container: NSPersistentContainer) {
		for store in container.persistentStoreCoordinator.persistentStores {
			try? container.persistentStoreCoordinator.remove(store)
		}
	}
}
