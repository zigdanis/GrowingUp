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
			.peopleReordered(peopleCount: 3)
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
		XCTAssertEqual(Set(events.map(\.name)).count, 12, "Every event has its own name")
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
