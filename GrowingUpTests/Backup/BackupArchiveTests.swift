import XCTest

@testable import Core
@testable import GrowingUp

final class BackupArchiveTests: XCTestCase {
	private var library: BackupLibraryFixture!
	private var archive: BackupArchive!

	override func setUpWithError() throws {
		library = try BackupLibraryFixture()
		archive = BackupArchive(directory: library.root.appendingPathComponent("Archives", isDirectory: true))
	}

	override func tearDownWithError() throws {
		try library.remove()
	}

	private func snapshot() async throws -> LibrarySnapshot {
		let picture = UUID()
		try library.addPerson(name: "Mia", order: 1, appPic: picture, files: ["\(picture.uuidString).png": "picture"])
		try library.addPerson(name: "Leo", order: 2)
		return try await library.gateway.snapshot(
			createdAt: Date(timeIntervalSince1970: 1_800_000_000), appVersion: "3.2 (50)", deviceModel: "iPhone")
	}

	/// Zips `folder` as Foundation does for Files, with the folder itself at the top of the zip.
	private func zip(_ folder: URL) throws -> URL {
		let destination = library.root.appendingPathComponent("\(UUID().uuidString).zip")
		var coordinationError: NSError?
		var copyError: Error?
		NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zip in
			do { try FileManager.default.copyItem(at: zip, to: destination) } catch { copyError = error }
		}
		if let error = coordinationError ?? copyError { throw error }
		return destination
	}

	func testAnExportOpensAgainWithEveryPersonAndPhoto() async throws {
		let snapshot = try await snapshot()
		let url = try archive.export(snapshot)
		XCTAssertEqual(url.lastPathComponent, BackupArchive.fileName(for: snapshot.document.createdAt))
		XCTAssertTrue(url.lastPathComponent.hasPrefix("GrowingUp-backup-"))

		let opened = try archive.open(url)

		// Dates travel to the millisecond, so the people compare without them.
		XCTAssertEqual(opened.document.people.map(\.id), snapshot.document.people.map(\.id))
		XCTAssertEqual(opened.document.people.map(\.appPicId), snapshot.document.people.map(\.appPicId))
		XCTAssertEqual(opened.document.photos, snapshot.document.photos)
		let photo = try XCTUnwrap(snapshot.document.photos.first)
		XCTAssertEqual(try Data(contentsOf: XCTUnwrap(opened.photoFiles[photo.file])), Data("picture".utf8))
	}

	func testAnUnpackedBackupZippedAgainStillOpensAndOtherFilesAreIgnored() async throws {
		let snapshot = try await snapshot()
		let folder = library.root.appendingPathComponent("GrowingUp backup", isDirectory: true)
		try BackupFolder(url: folder).write(snapshot)
		try Data("notes".utf8).write(to: folder.appendingPathComponent("notes.txt"))

		let opened = try archive.open(zip(folder))

		XCTAssertEqual(opened.document.people.map(\.name), ["Mia", "Leo"])
		let unpacked = try XCTUnwrap(opened.photoFiles.values.first).deletingLastPathComponent().deletingLastPathComponent()
		XCTAssertFalse(FileManager.default.fileExists(atPath: unpacked.appendingPathComponent("notes.txt").path))
	}

	func testAFileThatIsNoBackupIsSaidToBeOne() throws {
		let folder = library.root.appendingPathComponent("Holiday", isDirectory: true)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		try Data("photo".utf8).write(to: folder.appendingPathComponent("beach.png"))
		let text = library.root.appendingPathComponent("notes.zip")
		try Data("not a zip".utf8).write(to: text)
		for url in [try zip(folder), text] {
			XCTAssertThrowsError(try archive.open(url)) { XCTAssertEqual($0 as? BackupError, .notABackup) }
		}
	}

	func testABackupMissingAPhotoIsNotOpened() async throws {
		let snapshot = try await snapshot()
		let folder = library.root.appendingPathComponent("Broken", isDirectory: true)
		try BackupFolder(url: folder).write(snapshot)
		let photos = folder.appendingPathComponent(BackupFolder.photosFolderName)
		for name in try FileManager.default.contentsOfDirectory(atPath: photos.path) {
			try Data("damaged".utf8).write(to: photos.appendingPathComponent(name))
		}
		XCTAssertThrowsError(try archive.open(zip(folder))) { XCTAssertEqual($0 as? BackupError, .photoUnavailable) }
	}

	func testABackupLargerThanTheLimitIsNotUnpacked() async throws {
		let url = try archive.export(try await snapshot())
		let small = BackupArchive(directory: archive.directory.appendingPathComponent("Small"), maximumSize: 3)
		XCTAssertThrowsError(try small.open(url)) { XCTAssertEqual($0 as? BackupError, .notABackup) }
	}

	func testRemovingAllLeavesNothingBehind() async throws {
		_ = try archive.export(try await snapshot())
		archive.removeAll()
		XCTAssertFalse(FileManager.default.fileExists(atPath: archive.directory.path))
	}
}
