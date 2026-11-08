import XCTest

@testable import Core

/// A backup folder written again and again, as the iCloud backup writes its install's folder after each change.
final class BackupFolderTests: XCTestCase {
	private var library: BackupLibraryFixture!
	private var folder: BackupFolder!

	override func setUpWithError() throws {
		library = try BackupLibraryFixture()
		folder = BackupFolder(url: library.root.appendingPathComponent("Backups/Install A", isDirectory: true))
	}

	override func tearDownWithError() throws {
		try library.remove()
	}

	private var photosURL: URL { folder.url.appendingPathComponent(BackupFolder.photosFolderName) }

	private func photoFiles() throws -> Set<String> {
		Set(try FileManager.default.contentsOfDirectory(atPath: photosURL.path))
	}

	/// Adds a person with a picture of their own and returns the library's snapshot.
	private func addPersonWithPicture(_ name: String, at seconds: TimeInterval) async throws -> LibrarySnapshot {
		let picture = UUID()
		try library.addPerson(name: name, appPic: picture, files: ["\(picture.uuidString).png": "picture of \(name)"])
		return try await library.gateway.snapshot(
			createdAt: Date(timeIntervalSince1970: seconds), appVersion: "3.2 (50)", deviceModel: "iPhone")
	}

	func testAWriteKeepsTheCompleteBackupItReplacesAsThePreviousCopy() async throws {
		let first = try await addPersonWithPicture("Mia", at: 1_000)
		try folder.write(first)
		XCTAssertThrowsError(try folder.document(previous: true), "A first write has nothing to keep")
		let second = try await addPersonWithPicture("Leo", at: 2_000)
		try folder.write(second)

		XCTAssertEqual(try folder.document().people.map(\.name), ["Mia", "Leo"])
		XCTAssertEqual(try folder.document(previous: true).people.map(\.name), ["Mia"])
		XCTAssertEqual(try folder.load(previous: true).document.createdAt, first.document.createdAt)
		XCTAssertTrue(folder.isIntact)
	}

	func testPhotosNeitherCopyRefersToArePrunedAndOtherFilesStay() async throws {
		let first = try await addPersonWithPicture("Mia", at: 1_000)
		try folder.write(first)
		try Data("notes".utf8).write(to: photosURL.appendingPathComponent("notes.txt"))
		try folder.write(try await addPersonWithPicture("Leo", at: 2_000))
		let miaFile = try XCTUnwrap(first.document.photos.first?.file)
		let mia = try XCTUnwrap(library.storedPeople().first { $0.name == "Mia" })
		try library.removePerson(mia.id)

		let third = try await addPersonWithPicture("Ava", at: 3_000)
		try folder.write(third)
		XCTAssertTrue(try photoFiles().contains(miaFile), "The previous copy keeps its photos")

		let fourth = try await addPersonWithPicture("Zoe", at: 4_000)
		try folder.write(fourth)
		XCTAssertEqual(
			try photoFiles(), Set(fourth.document.photos.map(\.file) + third.document.photos.map(\.file) + ["notes.txt"]),
			"Mia's photo goes with the last copy that had her; only photo files are pruned")
	}

	func testAnIncompleteBackupNeverReplacesTheGoodPreviousCopy() async throws {
		let first = try await addPersonWithPicture("Mia", at: 1_000)
		try folder.write(first)
		let second = try await addPersonWithPicture("Leo", at: 2_000)
		try folder.write(second)
		let leoFile = try XCTUnwrap(second.document.photos.map(\.file).first { !first.document.photos.map(\.file).contains($0) })
		try FileManager.default.removeItem(at: photosURL.appendingPathComponent(leoFile))
		XCTAssertFalse(folder.isIntact)
		// Leo is gone from the library too, so the next write doesn't bring his photo back.
		try library.removePerson(try XCTUnwrap(library.storedPeople().first { $0.name == "Leo" }).id)

		try folder.write(try await addPersonWithPicture("Ava", at: 3_000))

		XCTAssertEqual(try folder.document(previous: true).people.map(\.name), ["Mia"], "The incomplete copy is not kept")
		XCTAssertEqual(try folder.document().people.map(\.name), ["Mia", "Ava"])
		XCTAssertTrue(folder.isIntact)
	}

	func testAWritePutsBackAPhotoTheLatestCopyLacks() async throws {
		let first = try await addPersonWithPicture("Mia", at: 1_000)
		try folder.write(first)
		try FileManager.default.removeItem(at: photosURL.appendingPathComponent(try XCTUnwrap(first.document.photos.first?.file)))

		try folder.write(try await addPersonWithPicture("Leo", at: 2_000))

		XCTAssertTrue(folder.isIntact)
		XCTAssertEqual(try folder.document(previous: true).people.map(\.name), ["Mia"], "Complete again, the copy is kept")
	}

	func testAMissingOrDamagedPhotoFailsTheLoadAsRetryable() async throws {
		let snapshot = try await addPersonWithPicture("Mia", at: 1_000)
		try folder.write(snapshot)
		let file = photosURL.appendingPathComponent(try XCTUnwrap(snapshot.document.photos.first?.file))

		// The same size, but other bytes: only the digest shows it.
		try Data("picture of Mib".utf8).write(to: file)
		XCTAssertThrowsError(try folder.load()) { XCTAssertEqual($0 as? BackupError, .photoUnavailable) }

		try Data("damaged".utf8).write(to: file)
		XCTAssertFalse(folder.isIntact, "A file of the wrong size is damaged")
		try folder.write(snapshot)
		XCTAssertNoThrow(try folder.load(), "A write repairs a damaged photo")

		try FileManager.default.removeItem(at: file)
		XCTAssertFalse(folder.isIntact)
		XCTAssertThrowsError(try folder.load()) { XCTAssertEqual($0 as? BackupError, .photoUnavailable) }
	}

	func testALoadIntoAStagingFolderCopiesTheCheckedPhotos() async throws {
		let snapshot = try await addPersonWithPicture("Mia", at: 1_000)
		try folder.write(snapshot)
		let staging = library.root.appendingPathComponent("Staging Area", isDirectory: true)
		try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

		let loaded = try folder.load(stagingDirectory: staging)

		let file = try XCTUnwrap(snapshot.document.photos.first?.file)
		XCTAssertEqual(loaded.photoFiles[file], staging.appendingPathComponent(file))
		XCTAssertEqual(try String(contentsOf: staging.appendingPathComponent(file), encoding: .utf8), "picture of Mia")
	}

	func testTheLatestDocumentFallsBackToThePreviousCopyWhenDamaged() async throws {
		try folder.write(try await addPersonWithPicture("Mia", at: 1_000))
		try folder.write(try await addPersonWithPicture("Leo", at: 2_000))
		try Data("{".utf8).write(to: folder.url.appendingPathComponent(BackupFolder.documentName))

		XCTAssertEqual(try folder.document().people.map(\.name), ["Mia"])
		XCTAssertFalse(folder.isIntact)
		XCTAssertTrue(folder.hasDocument)
	}
}
