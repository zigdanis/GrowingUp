import XCTest

@testable import Core

final class BackupCodecTests: XCTestCase {
	private let digest = String(repeating: "ab", count: 32)

	private func document(photos: [BackupPhoto] = [], formatVersion: Int = BackupDocument.currentFormatVersion) -> BackupDocument {
		var person = BackupPerson(
			Person(
				id: UUID(), name: "Mia", birthday: Date(timeIntervalSince1970: 1_600_000_000.5), appPicId: nil, widgetPicId: nil,
				isOnWidget: true, createdDate: Date(timeIntervalSince1970: 1_700_000_000.125), celebratesBirthdays: false, displayOrder: 3))
		person.appPicCrop = PhotoCrop(minX: 0.1, minY: 0.2, width: 0.3, height: 0.4)
		var document = BackupDocument(createdAt: Date(), appVersion: "3.2 (50)", deviceModel: "iPhone", people: [person], photos: photos)
		document.formatVersion = formatVersion
		return document
	}

	func testADocumentReadsBackAsItWasWrittenToTheMillisecond() throws {
		let photo = BackupPhoto(name: "\(UUID().uuidString).heic", file: "\(digest).heic", size: 12)
		let written = document(photos: [photo])
		let read = try BackupCodec.decode(BackupCodec.encode(written))
		XCTAssertEqual(read.people, written.people)
		XCTAssertEqual(read.photos, [photo])
		XCTAssertEqual(read.createdAt.timeIntervalSince1970, written.createdAt.timeIntervalSince1970, accuracy: 0.001)
	}

	func testANewerFormatAsksForAnUpdate() throws {
		let data = try BackupCodec.encode(document(formatVersion: BackupDocument.currentFormatVersion + 1))
		XCTAssertThrowsError(try BackupCodec.decode(data)) { XCTAssertEqual($0 as? BackupError, .newerVersion) }
	}

	func testAnythingElseIsNotABackup() throws {
		let unsafe = [
			BackupPhoto(name: "../\(UUID().uuidString).png", file: "\(digest).png", size: 1),
			BackupPhoto(name: "\(UUID().uuidString).png", file: "../\(digest).png", size: 1),
			BackupPhoto(name: "\(UUID().uuidString).png", file: "\(digest).heic", size: 1),
			BackupPhoto(name: "notes.txt", file: "\(digest).png", size: 1)
		]
		for photo in unsafe {
			XCTAssertThrowsError(try BackupCodec.decode(BackupCodec.encode(document(photos: [photo]))), photo.name) {
				XCTAssertEqual($0 as? BackupError, .notABackup)
			}
		}
		let manifest = Data(#"{"format": "growingup-preserved-store", "formatVersion": 1}"#.utf8)
		for data in [Data("not json".utf8), manifest, Data(#"{"format": "growingup-backup", "formatVersion": 1}"#.utf8)] {
			XCTAssertThrowsError(try BackupCodec.decode(data)) { XCTAssertEqual($0 as? BackupError, .notABackup) }
		}
	}

	func testAPictureWithoutItsFileIsNotABackup() throws {
		var written = document()
		written.people[0].appPicId = UUID()
		XCTAssertThrowsError(try BackupCodec.decode(BackupCodec.encode(written))) { XCTAssertEqual($0 as? BackupError, .notABackup) }
	}

	func testPhotoFilesAreNamedByTheirDigestWithTheirOwnExtension() {
		XCTAssertEqual(BackupCodec.photoFile(digest: digest, name: "\(UUID().uuidString).HEIC"), "\(digest).heic")
		XCTAssertTrue(BackupCodec.isPhotoFile("\(digest).jpg"))
		XCTAssertFalse(BackupCodec.isPhotoFile("\(digest.uppercased()).png"))
		XCTAssertFalse(BackupCodec.isPhotoFile("\(digest).gif"))
		XCTAssertFalse(BackupCodec.isPhotoFile("photos/\(digest).png"))
	}
}
