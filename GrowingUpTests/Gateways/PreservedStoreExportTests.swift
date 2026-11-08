import XCTest

@testable import Core

final class PreservedStoreExportTests: XCTestCase {
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

	func testExportOfAnInterruptedPhotoPassIncludesTheLinkedAndTheLoosePhotos() throws {
		let folder = try fixture.legacyFolder(named: "GrowingUp.sqlite.backup-2026-10-21T08-15-30Z-I")
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

	func testExportIsOneArchiveAndLeavesThePreservedFilesAsTheyWere() throws {
		try fixture.writeFamily()
		let backup = try SQLiteStoreBackup().moveStore(at: store, cause: .incompatibleModel(code: 134_100), date: Date(timeIntervalSince1970: 0))
		let photo = UUID()
		try Data("photo".utf8).write(to: root.appendingPathComponent("\(photo.uuidString).png"))
		let kept = try library.preservePhotos(of: try XCTUnwrap(library.stores().first))
		let before = try fixture.digests(in: backup)
		let archive = try library.export(kept, now: Date(timeIntervalSince1970: 60))
		XCTAssertEqual(archive.lastPathComponent, "GrowingUp-earlier-data-1970-01-01.zip")
		XCTAssertEqual(try Data(contentsOf: archive).prefix(2), Data("PK".utf8))
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: exports.path), [archive.lastPathComponent], "Staging is removed")
		XCTAssertEqual(try fixture.digests(in: backup), before)
		XCTAssertEqual(try library.stores(), [kept])
		library.removeExports()
		XCTAssertFalse(FileManager.default.fileExists(atPath: exports.path))
	}

	func testStagedArchiveListsEveryFileWithItsChecksum() throws {
		try fixture.writeFamily()
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
		try fixture.writeFamily()
		let backup = try SQLiteStoreBackup().moveStore(at: store, date: Date(timeIntervalSince1970: 0))
		let preserved = try XCTUnwrap(library.stores().first)
		let before = try fixture.digests(in: backup)
		// A photo that vanishes between listing and staging fails the export.
		let missing = root.appendingPathComponent("\(UUID().uuidString).png")
		try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
		XCTAssertThrowsError(
			try PreservedStoreArchiver(storeFileName: "GrowingUp.sqlite").stage(
				store: preserved, folder: backup, photos: [missing], exportedAt: Date(), in: exports))
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: exports.path), [])
		XCTAssertEqual(try fixture.digests(in: backup), before)
		// A retry once the cause is gone succeeds.
		XCTAssertNoThrow(try library.export(preserved, now: Date()))
	}

}
