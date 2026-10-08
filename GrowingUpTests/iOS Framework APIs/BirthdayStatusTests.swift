import Core
import XCTest

final class BirthdayStatusTests: XCTestCase {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	func testFourteenCalendarDaysInclusiveAndYearRollover() {
		let birthday = date(2020, 1, 1, 18)
		let status = BirthdayStatus(birthday: birthday, now: date(2026, 12, 18, 23), calendar: calendar)
		XCTAssertTrue(status.isUpcoming)
		XCTAssertEqual(status.daysRemaining, 14)
		XCTAssertEqual(status.date, date(2027, 1, 1))
		XCTAssertFalse(BirthdayStatus(birthday: birthday, now: date(2026, 12, 17), calendar: calendar).isUpcoming)
	}

	func testCountdownThresholdsUseMidnightAndNeverShowZeroBeforeBirthday() {
		let birthday = date(2020, 1, 16, 6)
		let midnight = date(2027, 1, 16)
		for (remaining, expected) in [
			(86_400.0, DateComponents(day: 1)), (86_399.0, DateComponents(hour: 24)),
			(3_600.0, DateComponents(hour: 1)), (3_599.0, DateComponents(minute: 60)),
			(60.0, DateComponents(minute: 1)), (59.0, DateComponents(second: 59)),
			(0.1, DateComponents(second: 1))
		] {
			let status = BirthdayStatus(birthday: birthday, now: midnight.addingTimeInterval(-remaining), calendar: calendar)
			XCTAssertEqual(status.countdown, expected)
			XCTAssertFalse(status.isToday)
		}
		for hour in [0, 6, 23] {
			XCTAssertTrue(BirthdayStatus(birthday: birthday, now: date(2027, 1, 16, hour), calendar: calendar).isToday)
		}
		XCTAssertEqual(BirthdayStatus(birthday: birthday, now: date(2027, 1, 17), calendar: calendar).date, date(2028, 1, 16))
	}

	func testLeapBirthdayFallsOnFebruary28OnlyInNonLeapYears() {
		let birthday = date(2020, 2, 29, 18)
		XCTAssertTrue(BirthdayStatus(birthday: birthday, now: date(2027, 2, 28), calendar: calendar).isToday)
		let leap = BirthdayStatus(birthday: birthday, now: date(2028, 2, 28), calendar: calendar)
		XCTAssertFalse(leap.isToday)
		XCTAssertEqual(leap.date, date(2028, 2, 29))
		XCTAssertTrue(BirthdayStatus(birthday: birthday, now: date(2028, 2, 29, 23), calendar: calendar).isToday)
	}

	func testDayCountUsesCalendarAcrossDaylightSavingAndLocalMidnight() {
		var calendar = self.calendar
		calendar.timeZone = TimeZone(identifier: "America/New_York")!
		let birthday = calendar.date(from: DateComponents(year: 2020, month: 3, day: 15, hour: 18))!
		let now = calendar.date(from: DateComponents(year: 2027, month: 3, day: 1, hour: 12))!
		let status = BirthdayStatus(birthday: birthday, now: now, calendar: calendar)
		XCTAssertEqual(status.daysRemaining, 14)
		XCTAssertEqual(calendar.component(.hour, from: status.date), 0)
		XCTAssertTrue(status.isUpcoming)
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
	}
}
