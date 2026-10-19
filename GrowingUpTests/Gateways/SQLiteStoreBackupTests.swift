import XCTest

@testable import Core

final class SQLiteStoreBackupTests: XCTestCase {
	private var directory: URL!
	private var store: URL { directory.appendingPathComponent("GrowingUp.sqlite") }

	override func setUpWithError() throws {
		directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: directory)
	}

	func testBackupPreservesEveryByteOfSQLiteAndSidecarsNextToStore() throws {
		try writeFamily()
		let backup = try SQLiteStoreBackup().moveStore(at: store, date: Date(timeIntervalSince1970: 0))
		XCTAssertEqual(backup.deletingLastPathComponent(), directory)
		XCTAssertTrue(backup.lastPathComponent.hasPrefix("GrowingUp.sqlite.backup-1970-01-01T00-00-00Z-"))
		for suffix in ["", "-wal", "-shm"] {
			XCTAssertFalse(FileManager.default.fileExists(atPath: store.path + suffix))
			XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent(store.lastPathComponent + suffix)), Data("saved\(suffix)".utf8))
		}
	}

	func testMissingSidecarsAreAllowedAndSameTimestampNeverOverwritesBackup() throws {
		try Data("first".utf8).write(to: store)
		let date = Date(timeIntervalSince1970: 0)
		let first = try SQLiteStoreBackup().moveStore(at: store, date: date)
		try Data("second".utf8).write(to: store)
		let second = try SQLiteStoreBackup().moveStore(at: store, date: date)
		XCTAssertNotEqual(first, second)
		XCTAssertEqual(try Data(contentsOf: first.appendingPathComponent(store.lastPathComponent)), Data("first".utf8))
		XCTAssertEqual(try Data(contentsOf: second.appendingPathComponent(store.lastPathComponent)), Data("second".utf8))
	}

	func testMissingMainStoreLeavesOrphanedSidecarUntouched() throws {
		let wal = URL(fileURLWithPath: store.path + "-wal")
		try Data("saved".utf8).write(to: wal)
		XCTAssertThrowsError(try SQLiteStoreBackup().moveStore(at: store))
		XCTAssertEqual(try Data(contentsOf: wal), Data("saved".utf8))
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [wal.lastPathComponent])
	}

	func testFailedSidecarOrMainMoveRestoresPreviouslyMovedFiles() throws {
		for failedSuffix in ["-shm", ""] {
			try writeFamily()
			let mover = SQLiteStoreBackup { source, destination in
				if source == URL(fileURLWithPath: self.store.path + failedSuffix) {
					throw CocoaError(.fileWriteNoPermission)
				}
				try FileManager.default.moveItem(at: source, to: destination)
			}
			XCTAssertThrowsError(try mover.moveStore(at: store))
			for suffix in ["", "-wal", "-shm"] {
				XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: store.path + suffix)), Data("saved\(suffix)".utf8))
			}
		}
	}

	func testInterruptedMovesResumeWithoutDroppingWALOrOverwritingBackup() throws {
		for movedSuffixes in [["-wal"], ["-wal", "-shm", ""]] {
			try writeFamily()
			let backup = directory.appendingPathComponent("GrowingUp.sqlite.backup-\(UUID().uuidString)", isDirectory: true)
			try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
			try Data(backup.lastPathComponent.utf8).write(to: store.appendingPathExtension("recovery"), options: .atomic)
			for suffix in movedSuffixes {
				try FileManager.default.moveItem(at: URL(fileURLWithPath: store.path + suffix),
					to: backup.appendingPathComponent(store.lastPathComponent + suffix))
			}
			XCTAssertEqual(try SQLiteStoreBackup().resumePendingMove(at: store), backup)
			XCTAssertNil(try SQLiteStoreBackup().resumePendingMove(at: store))
			for suffix in ["", "-wal", "-shm"] {
				XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent(store.lastPathComponent + suffix)), Data("saved\(suffix)".utf8))
				XCTAssertFalse(FileManager.default.fileExists(atPath: store.path + suffix))
			}
		}
	}

	func testResumeCollisionPreservesBothCopiesAndKeepsJournal() throws {
		try writeFamily()
		let backup = directory.appendingPathComponent("GrowingUp.sqlite.backup-collision", isDirectory: true)
		try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
		let journal = store.appendingPathExtension("recovery")
		try Data(backup.lastPathComponent.utf8).write(to: journal, options: .atomic)
		let preservedWAL = backup.appendingPathComponent("GrowingUp.sqlite-wal")
		try Data("other WAL".utf8).write(to: preservedWAL)
		XCTAssertThrowsError(try SQLiteStoreBackup().resumePendingMove(at: store))
		XCTAssertTrue(FileManager.default.fileExists(atPath: journal.path))
		XCTAssertEqual(try Data(contentsOf: preservedWAL), Data("other WAL".utf8))
		XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: store.path + "-wal")), Data("saved-wal".utf8))
	}

	private func writeFamily() throws {
		for suffix in ["", "-wal", "-shm"] {
			try Data("saved\(suffix)".utf8).write(to: URL(fileURLWithPath: store.path + suffix))
		}
	}
}
