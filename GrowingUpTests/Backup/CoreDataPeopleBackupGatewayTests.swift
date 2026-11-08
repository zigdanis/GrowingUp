import XCTest

@testable import Core

final class CoreDataPeopleBackupGatewayTests: XCTestCase {
	private var source: BackupLibraryFixture!
	private var target: BackupLibraryFixture!

	override func setUpWithError() throws {
		source = try BackupLibraryFixture()
		target = try BackupLibraryFixture()
	}

	override func tearDownWithError() throws {
		try source.remove()
		try target.remove()
	}

	func testSnapshotHoldsEveryPersonInMosaicOrderWithEachPhotoFileOnce() async throws {
		let picture = UUID()
		let original = UUID()
		let second = try source.addPerson(name: "Leo", order: 2)
		let first = try source.addPerson(
			name: "Mia", order: 1, onWidget: true, appPic: picture, originalPic: original,
			files: ["\(picture.uuidString).png": "picture", "\(original.uuidString).heic": "original", "unrelated.txt": "x"])
		let snapshot = try await source.gateway.snapshot(createdAt: Date(), appVersion: "3.2 (50)", deviceModel: "iPhone")
		XCTAssertEqual(snapshot.document.people.map(\.id), [first, second])
		XCTAssertEqual(snapshot.document.people.first?.isOnWidget, true)
		XCTAssertEqual(
			Set(snapshot.document.photos.map(\.name)), ["\(picture.uuidString).png", "\(original.uuidString).heic"],
			"A picture in two roles is one file; files nobody refers to stay out")
		for photo in snapshot.document.photos {
			XCTAssertTrue(BackupCodec.isPhotoFile(photo.file))
			XCTAssertEqual(try ArchivedFile.digest(of: XCTUnwrap(snapshot.photoSources[photo.file])), BackupCodec.digest(inPhotoFile: photo.file))
		}
	}

	func testAPictureWhoseFileIsGoneIsLeftOutRatherThanNamedMissing() async throws {
		let picture = UUID()
		let original = UUID()
		try source.addPerson(name: "Mia", appPic: picture, originalPic: original, files: ["\(picture.uuidString).png": "picture"])
		let snapshot = try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone")
		let person = try XCTUnwrap(snapshot.document.people.first)
		XCTAssertEqual(person.appPicId, picture)
		XCTAssertNil(person.originalPicId)
		XCTAssertNil(person.appPicCrop, "A framing of the missing original goes with it")
		XCTAssertNoThrow(try source.roundTrip(snapshot), "The backup names no photo it lacks")
	}

	func testRestoreIntoAnEmptyLibraryAddsEveryoneWithTheirPhotosUnderNewNames() async throws {
		let picture = UUID()
		let original = UUID()
		let mia = try source.addPerson(
			name: "Mia", order: 1, onWidget: true, appPic: picture, originalPic: original,
			files: ["\(picture.uuidString).png": "picture", "\(original.uuidString).heic": "original"])
		let leo = try source.addPerson(name: "Leo", order: 2)
		let backup = try source.roundTrip(try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone"))

		let summary = try await target.gateway.restore(backup)

		XCTAssertEqual(summary, RestoreSummary(peopleAdded: 2, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: true))
		let people = try target.storedPeople()
		XCTAssertEqual(people.map(\.id), [mia, leo], "Identifiers and order come back")
		let restored = try XCTUnwrap(people.first)
		XCTAssertTrue(restored.isOnWidget)
		XCTAssertEqual(restored.appPicCrop, PhotoCrop(minX: 0.1, minY: 0.2, width: 0.5, height: 0.6))
		let newPicture = try XCTUnwrap(restored.appPicId)
		XCTAssertNotEqual(newPicture, picture, "Photos take new names, so no file of the library is ever replaced")
		XCTAssertEqual(restored.widgetPicId, newPicture, "A picture shared by two roles stays shared")
		XCTAssertEqual(try target.contents(of: "\(newPicture.uuidString).png"), "picture")
		XCTAssertEqual(try target.contents(of: "\(try XCTUnwrap(restored.originalPicId).uuidString).heic"), "original")
		XCTAssertEqual(try target.photoFiles().count, 2)
	}

	func testRestoreOnlyAddsWhoIsMissingAndNeverChangesAnyone() async throws {
		let mia = try step("add Mia") { try source.addPerson(name: "Mia", order: 1) }
		try step("add Leo") { try source.addPerson(name: "Leo", birthday: Date(timeIntervalSince1970: 1_500_033_600), order: 2) }
		try step("add Ava") { try source.addPerson(name: "Ava", order: 3) }
		let snapshot = try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone")
		let backup = try step("round trip") { try source.roundTrip(snapshot) }
		// Mia is here by identifier, renamed since; Leo was added again by hand after a reinstall. Both of Leo's birthdays
		// fall at midday UTC, on the same day in every time zone.
		try step("add Mia Rose") { try target.addPerson(name: "Mia Rose", order: 1, id: mia) }
		try step("add leo") { try target.addPerson(name: "  leo ", birthday: Date(timeIntervalSince1970: 1_500_033_600 + 3600), order: 2) }

		let summary = try await target.gateway.restore(backup)

		XCTAssertEqual(summary, RestoreSummary(peopleAdded: 1, peopleAlreadyPresent: 2, peopleOverLimit: 0, intoEmptyLibrary: false))
		XCTAssertEqual(try target.storedPeople().map(\.name), ["Mia Rose", "  leo ", "Ava"], "Nobody here changes; Ava joins the end")
		let again = try await target.gateway.restore(backup)
		XCTAssertEqual(again.peopleAdded, 0, "Restoring the same backup again adds nobody")
	}

	@discardableResult
	private func step<T>(_ name: String, _ body: () throws -> T) throws -> T {
		do {
			return try body()
		} catch {
			XCTFail("\(name): \(error)")
			throw error
		}
	}

	func testRestoreStopsAtThePeopleAndWidgetLimits() async throws {
		for index in 0..<8 {
			try source.addPerson(name: "Person \(index)", order: Int64(index), onWidget: index < Constants.widgetPeopleLimit)
		}
		let backup = try source.roundTrip(try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone"))
		for index in 0..<(Constants.peopleLimit - 5) {
			try target.addPerson(name: "Here \(index)", order: Int64(index), onWidget: index < 2)
		}

		let summary = try await target.gateway.restore(backup)

		XCTAssertEqual(summary.peopleAdded, 5)
		XCTAssertEqual(summary.peopleOverLimit, 3)
		let people = try target.storedPeople()
		XCTAssertEqual(people.count, Constants.peopleLimit)
		XCTAssertEqual(people.filter(\.isOnWidget).count, Constants.widgetPeopleLimit, "Only as many pins as the widget holds")
		XCTAssertEqual(people.suffix(5).map(\.name), (0..<5).map { "Person \($0)" }, "The first of the backup fit, in its order")
	}

	func testTwoPeopleOfOneBackupWithTheSameNameAndBirthdayAreBothRestored() async throws {
		try source.addPerson(name: "Sam", order: 1)
		try source.addPerson(name: "Sam", order: 2)
		let backup = try source.roundTrip(try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone"))
		let summary = try await target.gateway.restore(backup)
		XCTAssertEqual(summary.peopleAdded, 2)
	}

	func testAnOrdinaryAddAfterARestoreFilledTheLastPlaceIsRefused() async throws {
		for index in 0..<(Constants.peopleLimit - 1) {
			try target.addPerson(name: "Here \(index)", order: Int64(index))
		}
		try source.addPerson(name: "Mia")
		let backup = try source.roundTrip(try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone"))
		_ = try await target.gateway.restore(backup)

		let persons = CoreDataPersonsGateway(coreDataStack: target.stack)
		do {
			_ = try await persons.add(parameters: AddPersonParameters.createParameters())
			XCTFail("The library is full")
		} catch {
			XCTAssertEqual(error as? CoreError, .peopleLimitReached)
		}
		XCTAssertEqual(try target.storedPeople().count, Constants.peopleLimit)
	}

	func testARestoreThatFailsAddsNobodyAndLeavesNoFileBehind() async throws {
		let first = UUID()
		let second = UUID()
		try source.addPerson(name: "Mia", order: 1, appPic: first, files: ["\(first.uuidString).png": "one"])
		try source.addPerson(name: "Leo", order: 2, appPic: second, files: ["\(second.uuidString).png": "two"])
		let backup = try source.roundTrip(try await source.gateway.snapshot(createdAt: Date(), appVersion: "1", deviceModel: "iPhone"))
		// Leo's photo can't be read: Mia's, already written, must go again.
		let missing = try XCTUnwrap(backup.document.photos.first { $0.name.hasPrefix(second.uuidString) })
		var files = backup.photoFiles
		files[missing.file] = nil
		let existing = UUID()
		try target.addPerson(name: "Ava", appPic: existing, files: ["\(existing.uuidString).png": "kept"])

		do {
			_ = try await target.gateway.restore(LoadedBackup(document: backup.document, photoFiles: files))
			XCTFail("A photo that can't be read fails the restore")
		} catch {
			XCTAssertEqual(error as? BackupError, .photoUnavailable)
		}
		XCTAssertEqual(try target.storedPeople().map(\.name), ["Ava"])
		XCTAssertEqual(try target.photoFiles(), ["\(existing.uuidString).png"])
	}
}
