import Core
import XCTest

final class LockScreenTextTests: XCTestCase {
	private let english = Locale(identifier: "en")
	private let russian = Locale(identifier: "ru")

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	/// Leo was born on 3 June 2020 at 08:00.
	private var leo: Date { date(2020, 6, 3, 8) }

	func testOrdinaryDayShowsTheAgeWithoutBirthdayLine() {
		let lockScreen = text(leo, date(2025, 9, 15, 20, 30))
		XCTAssertEqual(lockScreen.compactAge, "5 years, 3 months")
		XCTAssertNil(lockScreen.birthdayLine)
		XCTAssertEqual(lockScreen.accessibilityLabel, "Leo, 5 years, 3 months")
	}

	func testBirthdayLastsTheWholeDay() {
		for now in [date(2026, 6, 3), date(2026, 6, 3, 5), date(2026, 6, 3, 10), date(2026, 6, 3, 23, 59)] {
			XCTAssertEqual(text(leo, now).birthdayLine, "Birthday today 🎂", "\(now)")
		}
		// The age itself counts from the birth time, while the celebration starts at midnight.
		XCTAssertEqual(text(leo, date(2026, 6, 3, 5)).compactAge, "5 years, 11 months")
		XCTAssertEqual(text(leo, date(2026, 6, 3, 10)).compactAge, "6 years")
		XCTAssertTrue(text(leo, date(2026, 6, 3, 10)).accessibilityLabel.hasPrefix("Leo, 6 years"))
		XCTAssertNil(text(leo, date(2026, 6, 4, 12)).birthdayLine)
	}

	func testBirthdayLineCountsDaysUpToAMonthAhead() {
		XCTAssertEqual(text(leo, date(2026, 5, 31, 12)).birthdayLine, "Birthday in 3 days")
		XCTAssertEqual(text(leo, date(2026, 6, 2, 12)).birthdayLine, "Birthday in 1 day")
		let twelveDays = text(leo, date(2026, 5, 22, 12))
		XCTAssertEqual(twelveDays.birthdayLine, "Birthday in 12 days")
		XCTAssertEqual(twelveDays.accessibilityLabel, "Leo, 5 years, 11 months, Birthday in 12 days")
		XCTAssertEqual(text(leo, date(2026, 5, 4, 12)).birthdayLine, "Birthday in 30 days")
		XCTAssertNil(text(leo, date(2026, 5, 3, 12)).birthdayLine)
		XCTAssertNil(text(leo, date(2026, 1, 3, 12)).birthdayLine)
	}

	func testNewbornCountsHoursAndHasNoBirthdayOnTheDayOfBirth() {
		let birth = date(2026, 1, 10, 10, 7).addingTimeInterval(30)
		let hours = text(birth, date(2026, 1, 10, 15, 20))
		XCTAssertEqual(hours.compactAge, "5 hours")
		XCTAssertNil(hours.birthdayLine)
		XCTAssertEqual(text(birth, date(2026, 1, 10, 10, 30)).compactAge, "0 hours")
		XCTAssertEqual(text(birth, date(2026, 1, 11, 12)).compactAge, "1 day")
		XCTAssertEqual(text(birth, date(2027, 1, 10)).birthdayLine, "Birthday today 🎂")
	}

	func testLeapDayBirthdayIsCelebratedOnFebruary28() {
		let birth = date(2020, 2, 29, 10)
		XCTAssertEqual(text(birth, date(2021, 2, 28, 9)).birthdayLine, "Birthday today 🎂")
		XCTAssertNotEqual(text(birth, date(2024, 2, 28, 9)).birthdayLine, "Birthday today 🎂")
		XCTAssertEqual(text(birth, date(2024, 2, 29, 9)).birthdayLine, "Birthday today 🎂")
	}

	func testRussianDayCountsUseThePluralRules() {
		for (now, days) in [
			(date(2026, 6, 2, 12), "1 день"), (date(2026, 5, 31, 12), "3 дня"),
			(date(2026, 5, 29, 12), "5 дней"), (date(2026, 5, 13, 12), "21 день")
		] {
			XCTAssertEqual(text(leo, now, name: "Лео", locale: russian).birthdayLine, "День рождения через \(days)")
		}
		XCTAssertEqual(text(leo, date(2026, 6, 3, 10), name: "Лео", locale: russian).birthdayLine, "Сегодня день рождения 🎂")
	}

	private func text(_ birthday: Date, _ now: Date, name: String = "Leo", locale: Locale? = nil) -> LockScreenText {
		LockScreenText(name: name, birthday: birthday, now: now, locale: locale ?? english, calendar: calendar)
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
