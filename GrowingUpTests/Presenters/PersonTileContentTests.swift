import Core
import XCTest

@testable import GrowingUp

final class PersonTileContentTests: XCTestCase {
	private let english = Locale(identifier: "en")
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	/// 15 January 2027 at 08:00, the UI tests' fixed clock.
	private var now: Date { date(2027, 1, 15, 8) }

	func testSecondaryUnitBecomesTheCaption() {
		let content = tile("Alice", born: date(2021, 10, 3, 6, 30))
		XCTAssertEqual(content.value, "5")
		XCTAssertEqual(content.unit, "years")
		XCTAssertEqual(content.caption, "and 3 months")
		XCTAssertFalse(content.isBirthday)
		XCTAssertEqual(content.accessibilityLabel, "Alice, 5 years, 3 months")
		XCTAssertEqual(tile("Farah", born: date(1996, 1, 14, 8)).caption, "and 1 day", "A birthday that just passed is not announced")
	}

	func testBirthdayCaptionsReplaceTheSecondaryUnitWithinAWeek() {
		let today = tile("Daria", born: date(2019, 1, 15, 6))
		XCTAssertTrue(today.isBirthday)
		XCTAssertEqual(today.caption, "Birthday today 🎂")
		XCTAssertEqual(today.accessibilityLabel, "Daria, 8 years, Birthday today 🎂")
		XCTAssertEqual(tile("Evan", born: date(2023, 1, 18, 8)).caption, "Birthday in 3 days")
		XCTAssertEqual(tile("Evan", born: date(2023, 1, 16, 8)).caption, "Birthday in 1 day")
		XCTAssertEqual(tile("Evan", born: date(2023, 1, 23, 8)).caption, "and 11 months", "Eight days ahead is not announced yet")
	}

	func testBirthdayAheadOfTheEntryDateIsNotAnnounced() {
		let content = tile("Unborn", born: now.addingTimeInterval(3 * 86_400))
		XCTAssertNil(content.caption)
		XCTAssertFalse(content.isBirthday)
		XCTAssertEqual(content.accessibilityLabel, "Unborn, 0 minutes")
	}

	func testNewbornShowsMinutesButNeverSeconds() {
		let midnight = date(2027, 1, 15)
		let content = tile("Clara", born: midnight.addingTimeInterval(-60), at: midnight.addingTimeInterval(30))
		XCTAssertEqual(content.value, "1")
		XCTAssertEqual(content.unit, "minute")
		XCTAssertNil(content.caption)
	}

	private func tile(_ name: String, born birthday: Date, at instant: Date? = nil) -> PersonTileContent {
		let person = WidgetPerson(id: UUID(), index: 0, name: name, birthday: birthday, image: nil)
		return PersonTileContent(person: person, date: instant ?? now, locale: english, calendar: calendar)
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
