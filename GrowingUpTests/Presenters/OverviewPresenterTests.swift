import Core
import XCTest

@testable import GrowingUp

@MainActor
final class OverviewPresenterTests: XCTestCase {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	func testChildLeadsWithYearsThenMonthsAndTheExactRemainder() {
		let presenter = makePresenter()
		presenter.tick(person: person(born: date(2020, 6, 3, 8)), now: date(2025, 9, 15, 12, 7, 33))
		XCTAssertEqual(presenter.primaryValue, "5")
		XCTAssertEqual(presenter.primaryUnit, "years")
		XCTAssertEqual(presenter.secondaryText, "and 3 months")
		XCTAssertEqual(presenter.tickerText, "12 days · 04:07:33")
		XCTAssertEqual(presenter.birthdayText, "Birthday in 261 days")
		XCTAssertEqual(presenter.accessibilityAge, "5 years and 3 months, Birthday in 261 days")
	}

	func testOnlyTheTickerChangesFromSecondToSecond() {
		let presenter = makePresenter()
		let child = person(born: date(2020, 6, 3, 8))
		presenter.tick(person: child, now: date(2025, 9, 15, 12, 7, 33))
		let summary = presenter.summary
		presenter.tick(person: child, now: date(2025, 9, 15, 12, 7, 34))
		XCTAssertEqual(presenter.summary, summary)
		XCTAssertEqual(presenter.secondaryText, "and 3 months")
		XCTAssertEqual(presenter.tickerText, "12 days · 04:07:34")
		// Seconds never become the secondary unit, even for a newborn of a few minutes.
		let newborn = person(born: date(2026, 1, 10, 10, 7, 30))
		presenter.tick(person: newborn, now: date(2026, 1, 10, 10, 52, 10))
		let minutes = presenter.summary
		presenter.tick(person: newborn, now: date(2026, 1, 10, 10, 52, 11))
		XCTAssertEqual(presenter.summary, minutes)
		XCTAssertNil(presenter.secondaryText)
		XCTAssertEqual(presenter.tickerText, "00:44:41")
	}

	func testNewbornCountsInDaysHoursAndMinutes() {
		let presenter = makePresenter()
		let newborn = person(born: date(2026, 1, 10, 10, 7, 30))
		presenter.tick(person: newborn, now: date(2026, 1, 12, 14, 20, 45))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit, presenter.secondaryText], ["2", "days", "and 4 hours"])
		XCTAssertEqual(presenter.tickerText, "04:13:15")
		XCTAssertEqual(presenter.birthdayText, "Birthday in 363 days")
		presenter.tick(person: newborn, now: date(2026, 1, 10, 13, 20, 45))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit, presenter.secondaryText], ["3", "hours", "and 13 minutes"])
		XCTAssertEqual(presenter.tickerText, "03:13:15")
		// The day of birth is not a birthday someone turns an age on.
		XCTAssertEqual(presenter.birthdayText, "Birthday today 🎂")
		XCTAssertEqual(presenter.accessibilityAge, "3 hours and 13 minutes, Birthday today 🎂")
		presenter.tick(person: newborn, now: date(2026, 1, 10, 10, 7, 30))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit], ["0", "minutes"])
		XCTAssertNil(presenter.secondaryText)
		XCTAssertEqual(presenter.tickerText, "00:00:00")
	}

	func testBirthdayAnnouncesTheAgeBeingTurnedAllDay() {
		let presenter = makePresenter()
		let child = person(born: date(2020, 1, 16, 6, 30))
		// Before the birth time the age still reads 6 years.
		presenter.tick(person: child, now: date(2027, 1, 16, 3))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit], ["6", "years"])
		XCTAssertEqual(presenter.secondaryText, "Turns 7 years old today 🎂")
		XCTAssertEqual(presenter.tickerText, "30 days · 20:30:00")
		XCTAssertEqual(presenter.birthdayText, "Birthday today 🎂")
		XCTAssertEqual(presenter.accessibilityAge, "6 years, Turns 7 years old today 🎂")
		presenter.tick(person: child, now: date(2027, 1, 16, 8))
		XCTAssertEqual(presenter.primaryValue, "7")
		XCTAssertEqual(presenter.secondaryText, "Turns 7 years old today 🎂")
		XCTAssertEqual(presenter.tickerText, "0 days · 01:30:00")
		presenter.tick(person: person(born: date(2026, 1, 16, 6, 30)), now: date(2027, 1, 16, 8))
		XCTAssertEqual(presenter.secondaryText, "Turns 1 year old today 🎂")
		// Hours are too fine to follow years, so the ticker carries them.
		presenter.tick(person: child, now: date(2027, 1, 17))
		XCTAssertNil(presenter.secondaryText)
		XCTAssertEqual(presenter.tickerText, "0 days · 17:30:00")
		XCTAssertEqual(presenter.birthdayText, "Birthday in 364 days")
	}

	func testBirthdayLineSwitchesUnitsAsMidnightApproaches() {
		let presenter = makePresenter()
		let child = person(born: date(2020, 1, 16, 6))
		let midnight = date(2027, 1, 16)
		for (remaining, expected) in [
			(86_400.0 * 14, "Birthday in 14 days"), (86_400.0, "Birthday in 1 day"), (86_399.0, "Birthday in 24 hours"),
			(3_599.0, "Birthday in 60 minutes"), (59.0, "Birthday in 59 seconds"), (0, "Birthday today 🎂")
		] {
			presenter.tick(person: child, now: midnight.addingTimeInterval(-remaining))
			XCTAssertEqual(presenter.birthdayText, expected)
		}
	}

	private func makePresenter() -> OverviewPresenter {
		OverviewPresenter(loadImage: { _ in UIImage() }, calendar: calendar, locale: Locale(identifier: "en"))
	}

	private func person(born birthday: Date) -> Person {
		var person = Person.createPerson()
		person.birthday = birthday
		return person
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
	}
}
