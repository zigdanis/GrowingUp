import Core
import CoreData
import XCTest

@testable import GrowingUp

/// Event names and properties form a fixed vocabulary of snake_case words, counts and flags: nothing a person typed or
/// picked, such as a name, a birthday or a photo, can travel in them.
@MainActor
final class AnalyticsEventTests: XCTestCase {
	private let calendar = Calendar(identifier: .gregorian)

	func testNamesKeysAndTextValuesAreSnakeCaseWords() {
		let saved = PersonSavedProperties(saved: makePerson(name: "Ada Lovelace"), previous: nil, people: [makePerson(name: "Ada")])
		let events: [AnalyticsEvent] = [
			.personViewed(source: .tile), .personViewed(source: .widget), .personViewed(source: .swipe),
			.widgetLinkOpened(target: .person), .widgetLinkOpened(target: .addPerson),
			.personEditorOpened(isNewPerson: true, source: .addButton), .personEditorOpened(isNewPerson: false, source: .viewer),
			.personEditorOpened(isNewPerson: true, source: .widget),
			.personEditorClosed(isNewPerson: true, outcome: .saved), .personEditorClosed(isNewPerson: false, outcome: .cancelled),
			.personEditorClosed(isNewPerson: false, outcome: .removed), .birthdayPickerOpened(.date),
			.birthdayPickerOpened(.time), .photoPicked(source: .photos), .photoPicked(source: .camera), .photoRemoved,
			.photoReframed, .widgetPictureFramed, .personSaved(saved), .personRemoved(peopleCount: 2),
			.peopleReordered(peopleCount: 3),
			.reviewPromptRequested(activeDays: 3, daysSinceFirstActive: 7, viewerVisits: 5, peopleWithPhotoCount: 2, requestNumber: 1),
			.preservedDataExported, .dataExported(peopleCount: 4),
			.dataRestored(source: .file, peopleAdded: 2, peopleAlreadyPresent: 1, peopleOverLimit: 0, intoEmptyLibrary: true),
			.widgetHintShown(shownLaunches: 1), .widgetHintOpened(shownLaunches: 2),
			.widgetHintDismissed(shownLaunches: 3)
		]
		let snakeCase = /^[a-z]+(_[a-z]+)*$/
		for event in events {
			XCTAssertNotNil(event.name.wholeMatch(of: snakeCase), event.name)
			for (key, value) in event.properties {
				XCTAssertNotNil(key.wholeMatch(of: snakeCase), "\(event.name).\(key)")
				if case .string(let text) = value {
					XCTAssertNotNil(text.wholeMatch(of: snakeCase), "\(event.name).\(key) = \(text)")
				}
			}
		}
		XCTAssertEqual(Set(events.map(\.name)).count, 19, "Every event has its own name")
	}

	func testASavedPersonIsDescribedByFlagsAndCountsOnly() {
		var previous = makePerson(name: "Mia")
		previous.isOnWidget = false
		var saved = previous
		saved.name = "Mia Rose"
		saved.isOnWidget = true
		saved.birthday = calendar.date(from: DateComponents(year: 2024, month: 4, day: 19, hour: 7, minute: 30))!
		var other = makePerson(name: "Leo")
		other.isOnWidget = false
		let properties = PersonSavedProperties(saved: saved, previous: previous, people: [saved, other], calendar: calendar)
		XCTAssertEqual(
			AnalyticsEvent.personSaved(properties).properties,
			[
				"mode": .string("edit"), "has_photo": .bool(true), "photo_changed": .bool(false), "has_birth_time": .bool(true),
				"on_widget": .bool(true), "celebrates_birthdays": .bool(true), "people_count": .int(2),
				"widget_people_count": .int(1)
			])
	}

	func testAWidgetPictureAloneCountsAsAPhotoAndANewPictureAsAChange() {
		var previous = makePerson(name: "Mia")
		var saved = previous
		saved.appPicId = nil
		previous.widgetPicId = nil
		let properties = PersonSavedProperties(saved: saved, previous: previous, people: [saved], calendar: calendar)
		XCTAssertTrue(properties.hasPhoto)
		XCTAssertTrue(properties.photoChanged)
		XCTAssertFalse(properties.hasBirthTime, "Midnight stands for an unknown time of birth")
		let added = PersonSavedProperties(saved: saved, previous: nil, people: [saved], calendar: calendar)
		XCTAssertTrue(added.isNewPerson)
		XCTAssertEqual(AnalyticsEvent.personSaved(added).properties["mode"], .string("create"))
	}

	func testAReportedErrorKeepsOnlyItsDomainCodeAndType() {
		let error = NSError(
			domain: NSCocoaErrorDomain, code: NSValidationMissingMandatoryPropertyError,
			userInfo: [NSLocalizedDescriptionKey: "Ada Lovelace is invalid", "NSValidationErrorObject": "Ada Lovelace"])
		let sanitized = AnalyticsFailure(operation: "save_person", error: error).sanitizedError
		XCTAssertEqual(sanitized.domain, NSCocoaErrorDomain)
		XCTAssertEqual(sanitized.code, NSValidationMissingMandatoryPropertyError)
		XCTAssertEqual(Array(sanitized.userInfo.keys), [NSLocalizedDescriptionKey])
		XCTAssertFalse(sanitized.localizedDescription.contains("Ada"))
		let coreError = AnalyticsFailure(operation: "save_person", error: CoreError(message: "Ada Lovelace")).sanitizedError
		XCTAssertFalse(coreError.localizedDescription.contains("Ada"), "A CoreError message never travels")
		XCTAssertTrue(coreError.localizedDescription.contains("CoreError"))
	}

	func testAWrappedErrorKeepsTheCauseItWrapsWithoutItsText() {
		let cause = NSError(
			domain: NSCocoaErrorDomain, code: NSPersistentStoreSaveConflictsError,
			userInfo: [NSLocalizedDescriptionKey: "Ada Lovelace conflicts", "conflictList": ["Ada Lovelace"]])
		let wrapped = CoreError(error: CoreError(error: cause))
		let sameText = NSError(domain: "Other", code: 7, userInfo: [NSLocalizedDescriptionKey: "Ada Lovelace conflicts"])
		XCTAssertEqual(CoreError(error: cause), CoreError(error: sameText), "Equality is what the user is told")
		let sanitized = AnalyticsFailure(operation: "save_person", error: wrapped).sanitizedError
		XCTAssertEqual(sanitized.domain, NSCocoaErrorDomain)
		XCTAssertEqual(sanitized.code, NSPersistentStoreSaveConflictsError, "Different causes stay apart in crash reports")
		XCTAssertEqual(Array(sanitized.userInfo.keys), [NSLocalizedDescriptionKey])
		XCTAssertFalse(sanitized.localizedDescription.contains("Ada"))
		XCTAssertTrue(sanitized.localizedDescription.contains("CoreError"))
	}

	/// A failed migration says why only in the errors underneath it, such as a full disk or a busy SQLite file.
	func testAReportedErrorNamesTheCausesUnderneathWithoutTheirText() {
		let sqlite = NSError(domain: NSSQLiteErrorDomain, code: 5, userInfo: [NSLocalizedDescriptionKey: "Ada Lovelace is busy"])
		let file = NSError(
			domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError,
			userInfo: [NSUnderlyingErrorKey: sqlite, NSFilePathErrorKey: "/Ada Lovelace.sqlite"])
		let validation = NSError(
			domain: NSCocoaErrorDomain, code: NSValidationMissingMandatoryPropertyError,
			userInfo: ["NSValidationErrorObject": "Ada Lovelace"])
		let migration = NSError(
			domain: NSCocoaErrorDomain, code: NSMigrationError,
			userInfo: [
				NSUnderlyingErrorKey: file, NSDetailedErrorsKey: [validation], NSSQLiteErrorDomain: 13,
				NSLocalizedDescriptionKey: "Ada Lovelace could not migrate"
			])
		let failure = AnalyticsFailure(operation: "load_people", error: migration)
		XCTAssertEqual(
			failure.causes,
			[
				"\(NSCocoaErrorDomain) \(NSFileWriteOutOfSpaceError)",
				"\(NSCocoaErrorDomain) \(NSValidationMissingMandatoryPropertyError)",
				"\(NSSQLiteErrorDomain) 13",
				"\(NSSQLiteErrorDomain) 5"
			])
		XCTAssertEqual(failure.sanitizedError.code, NSMigrationError, "The failure still groups by its own code")
		XCTAssertFalse(failure.causes.joined().contains("Ada"))
		XCTAssertEqual(AnalyticsFailure(operation: "save_person", error: CoreError(message: "Ada")).causes, [])
	}

	func testContextCarriesCountsOnly() {
		XCTAssertEqual(
			AnalyticsContext(peopleCount: 4, widgetPeopleCount: 2).properties,
			["people_count": .int(4), "widget_people_count": .int(2)])
	}

	private func makePerson(name: String) -> Person {
		var person = Person.createPerson()
		person.name = name
		person.birthday = calendar.date(from: DateComponents(year: 2024, month: 4, day: 19))!
		person.isOnWidget = true
		return person
	}
}
