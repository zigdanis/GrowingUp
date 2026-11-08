import XCTest

@testable import Core

/// The backups of every install in one root, as the iCloud container's `Backups` holds them.
final class BackupFolderStoreTests: XCTestCase {
	private var library: BackupLibraryFixture!
	private var store: BackupFolderStore!
	private let thisInstall = UUID()
	private let otherInstall = UUID()

	override func setUpWithError() throws {
		library = try BackupLibraryFixture()
		store = BackupFolderStore(root: library.root.appendingPathComponent("iCloud Container/Backups", isDirectory: true), access: .local)
	}

	override func tearDownWithError() throws {
		try library.remove()
	}

	private func snapshot(at seconds: TimeInterval, model: String = "iPhone") async throws -> LibrarySnapshot {
		try await library.gateway.snapshot(createdAt: Date(timeIntervalSince1970: seconds), appVersion: "3.2 (50)", deviceModel: model)
	}

	private func addPerson(_ name: String) throws {
		let picture = UUID()
		try library.addPerson(name: name, appPic: picture, files: ["\(picture.uuidString).png": "picture of \(name)"])
	}

	func testEachInstallIsOneCandidateNewestFirstAndThisDeviceIsMarked() async throws {
		try addPerson("Mia")
		try store.folder(for: otherInstall).write(try await snapshot(at: 1_000, model: "iPad"))
		try store.folder(for: otherInstall).write(try await snapshot(at: 2_000, model: "iPad"))
		try addPerson("Leo")
		try store.folder(for: thisInstall).write(try await snapshot(at: 3_000))
		// Neither is an install's folder.
		try FileManager.default.createDirectory(at: store.root.appendingPathComponent("Notes"), withIntermediateDirectories: true)
		try Data("x".utf8).write(to: store.root.appendingPathComponent("backup.json"))

		let candidates = store.candidates(thisInstall: thisInstall)

		XCTAssertEqual(candidates.map(\.folderName), [thisInstall.uuidString, otherInstall.uuidString])
		XCTAssertEqual(candidates.map(\.isThisDevice), [true, false])
		XCTAssertEqual(candidates.map(\.peopleCount), [2, 1])
		XCTAssertEqual(candidates.map(\.deviceModel), ["iPhone", "iPad"])
		XCTAssertEqual(candidates.last?.createdAt, Date(timeIntervalSince1970: 2_000), "A complete latest copy hides the earlier one")
		XCTAssertFalse(candidates.contains(where: \.isPreviousCopy))
	}

	func testAnEmptyLatestCopyListsTheEarlierOneToo() async throws {
		try addPerson("Mia")
		let folder = store.folder(for: otherInstall)
		try folder.write(try await snapshot(at: 1_000))
		try library.removePerson(try XCTUnwrap(library.storedPeople().first).id)
		try folder.write(try await snapshot(at: 2_000))

		let candidates = store.candidates(thisInstall: thisInstall)

		XCTAssertEqual(candidates.map(\.isPreviousCopy), [false, true])
		XCTAssertEqual(candidates.map(\.peopleCount), [0, 1])
		let earlier = try XCTUnwrap(candidates.last)
		XCTAssertNotEqual(earlier.id, candidates[0].id)
		let staging = library.root.appendingPathComponent("Staging", isDirectory: true)
		try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
		XCTAssertEqual(try store.load(earlier, stagingDirectory: staging).document.people.map(\.name), ["Mia"])
	}

	func testALatestCopyMissingAPhotoListsTheCompleteEarlierOne() async throws {
		try addPerson("Mia")
		let folder = store.folder(for: otherInstall)
		let first = try await snapshot(at: 1_000)
		try folder.write(first)
		try addPerson("Leo")
		let second = try await snapshot(at: 2_000)
		try folder.write(second)
		let leoFile = try XCTUnwrap(second.document.photos.map(\.file).first { !first.document.photos.map(\.file).contains($0) })
		try FileManager.default.removeItem(at: folder.url.appendingPathComponent("photos/\(leoFile)"))

		let candidates = store.candidates(thisInstall: thisInstall)

		XCTAssertEqual(candidates.map(\.peopleCount), [2, 1])
		XCTAssertEqual(candidates.map(\.isPreviousCopy), [false, true])
		XCTAssertNotNil(store.previousCandidate(folderName: otherInstall.uuidString, thisInstall: thisInstall))
	}

	func testAFolderOnlyICloudKnowsOfIsReadAndOneThatIsNoInstallIsNot() async throws {
		try addPerson("Mia")
		try store.folder(for: otherInstall).write(try await snapshot(at: 1_000))
		let candidates = store.candidates(thisInstall: thisInstall, knownFolders: [otherInstall.uuidString, "../Elsewhere"])
		XCTAssertEqual(candidates.map(\.folderName), [otherInstall.uuidString])
	}

	func testDeletingRemovesTheWholeInstallOrOnlyItsEarlierCopy() async throws {
		try addPerson("Mia")
		let folder = store.folder(for: otherInstall)
		try folder.write(try await snapshot(at: 1_000))
		try library.removePerson(try XCTUnwrap(library.storedPeople().first).id)
		try folder.write(try await snapshot(at: 2_000))
		let earlier = try XCTUnwrap(store.candidates(thisInstall: thisInstall).first(where: \.isPreviousCopy))

		try store.delete(earlier)
		XCTAssertEqual(store.candidates(thisInstall: thisInstall).map(\.isPreviousCopy), [false])
		XCTAssertTrue(folder.hasDocument)

		try store.delete(try XCTUnwrap(store.candidates(thisInstall: thisInstall).first))
		XCTAssertFalse(FileManager.default.fileExists(atPath: folder.url.path))
		XCTAssertTrue(store.candidates(thisInstall: thisInstall).isEmpty)
	}
}
