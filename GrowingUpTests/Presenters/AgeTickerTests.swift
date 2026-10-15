import Core
import XCTest

@testable import GrowingUp

final class AgeTickerTests: XCTestCase {
	private let english = Locale(identifier: "en")
	private let russian = Locale(identifier: "ru")

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	func testChildShowsTheDaysAndClockLeftOutOfYearsAndMonths() {
		// 5 years, 3 months, 12 days and 4:07:33.
		let birthday = date(2020, 6, 3, 8)
		let now = date(2025, 9, 15, 12, 7, 33)
		XCTAssertEqual(ticker(birthday, now, english), "12 days · 04:07:33")
		XCTAssertEqual(ticker(birthday, now, russian), "12 дней · 04:07:33")
		XCTAssertEqual(ticker(birthday, date(2025, 10, 4, 8), english), "1 day · 00:00:00")
	}

	func testBabyInMonthsAndDaysShowsOnlyTheClock() {
		// 11 months, 15 days and 2:00:05.
		XCTAssertEqual(ticker(date(2025, 2, 10, 10), date(2026, 1, 25, 12, 0, 5), english), "02:00:05")
	}

	func testNewbornShowsTheClockUnderDaysHoursAndMinutes() {
		let newborn = date(2026, 1, 10, 10, 7, 30)
		XCTAssertEqual(ticker(newborn, date(2026, 1, 12, 14, 20, 45), english), "04:13:15")
		XCTAssertEqual(ticker(newborn, date(2026, 1, 10, 13, 20, 45), english), "03:13:15")
		XCTAssertEqual(ticker(newborn, date(2026, 1, 10, 10, 52, 10), english), "00:44:40")
	}

	func testExactRemainderReadsAsZero() {
		let birthday = date(2020, 6, 3, 8)
		XCTAssertEqual(ticker(birthday, date(2025, 6, 3, 8), english), "0 days · 00:00:00")
		XCTAssertEqual(ticker(birthday, date(2025, 6, 3, 8), russian), "0 дней · 00:00:00")
		XCTAssertEqual(ticker(birthday, birthday, english), "00:00:00")
		XCTAssertEqual(ticker(birthday, date(2020, 1, 1), english), "00:00:00", "A future birthday reads as a zero age")
	}

	private func ticker(_ birthday: Date, _ now: Date, _ locale: Locale) -> String {
		let summary = AgeSummary(birthday: birthday, now: now, finestUnit: .minutes, calendar: calendar)
		return AgeTicker.text(birthday: birthday, now: now, summary: summary, calendar: calendar, locale: locale)
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
	}
}
