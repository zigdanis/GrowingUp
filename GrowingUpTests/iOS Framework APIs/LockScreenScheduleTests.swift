import Core
import XCTest

final class LockScreenScheduleTests: XCTestCase {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	/// Leo was born on 3 June 2020 at 08:00.
	private var leo: Date { date(2020, 6, 3, 8) }

	func testOrdinaryDaysChangeAtEveryMidnightAndOnTheMonthlyAnniversary() {
		let now = date(2025, 9, 25, 20, 30)
		let dates = entryDates(leo, now, limit: 14)
		XCTAssertEqual(dates.count, 14)
		XCTAssertEqual(dates.first, date(2025, 9, 26))
		XCTAssertTrue(dates.contains(date(2025, 10, 3)))
		XCTAssertTrue(dates.contains(date(2025, 10, 3, 8)), "5 years, 4 months starts at the birth time")
		XCTAssertEqual(dates.last, date(2025, 10, 8))
		assertIncreasing(dates, after: now)
	}

	func testEveryEntryChangesTheText() {
		let now = date(2025, 9, 25, 20, 30)
		var previous = text(leo, now)
		for moment in entryDates(leo, now, limit: 14) {
			let current = text(leo, moment)
			XCTAssertNotEqual(current, previous, "\(moment)")
			XCTAssertEqual(text(leo, moment.addingTimeInterval(-1)), previous, "\(moment)")
			previous = current
		}
	}

	func testNextBirthdayIsScheduledWithTheAgeChangeAtTheBirthTime() {
		let dates = entryDates(leo, date(2026, 5, 28, 12), limit: 14)
		XCTAssertTrue(dates.contains(date(2026, 6, 3)))
		XCTAssertTrue(dates.contains(date(2026, 6, 3, 8)))
		XCTAssertTrue(text(leo, date(2026, 6, 3)).isBirthday)
		XCTAssertFalse(text(leo, date(2026, 6, 3).addingTimeInterval(-1)).isBirthday)
	}

	func testLimitCapsTheEntries() {
		let now = date(2025, 9, 25, 20, 30)
		XCTAssertEqual(entryDates(leo, now, limit: 3), [date(2025, 9, 26), date(2025, 9, 27), date(2025, 9, 28)])
		XCTAssertEqual(entryDates(leo, now, limit: 1), [date(2025, 9, 26)])
		XCTAssertTrue(entryDates(leo, now, limit: 0).isEmpty)
	}

	func testHourlyEntriesOnlyDuringTheFirstDayOfLife() {
		let birth = date(2026, 1, 10, 10, 7).addingTimeInterval(30)
		let now = date(2026, 1, 10, 10, 30)
		let dates = entryDates(birth, now, limit: 40)
		assertIncreasing(dates, after: now)
		let oneDayOld = date(2026, 1, 11, 10, 7).addingTimeInterval(30)
		XCTAssertEqual(dates.first, date(2026, 1, 10, 11, 7).addingTimeInterval(30))
		XCTAssertTrue(dates.contains(date(2026, 1, 11)))
		XCTAssertTrue(dates.contains(oneDayOld))
		XCTAssertEqual(dates.filter { $0 <= oneDayOld && !isMidnight($0) }.count, 24)
		// Afterwards the age changes once a day at the birth time, 10:07:30.
		for moment in dates where moment > oneDayOld {
			XCTAssertTrue(isMidnight(moment) || moment.timeIntervalSince(calendar.startOfDay(for: moment)) == 36_450, "\(moment)")
		}
		// Hours and days never come closer than an hour; only a midnight can fall between two of them.
		for (earlier, later) in zip(dates, dates.dropFirst()) where later.timeIntervalSince(earlier) < 3_600 {
			XCTAssertTrue(isMidnight(earlier) || isMidnight(later), "\(earlier) – \(later)")
		}
		XCTAssertEqual(text(birth, oneDayOld.addingTimeInterval(-1)).compactAge, "23 hours")
		XCTAssertEqual(text(birth, oneDayOld).compactAge, "1 day")
	}

	func testOlderPeopleNeverGetEntriesWithinAnHour() {
		let dates = entryDates(leo, date(2026, 5, 28, 12), limit: 14)
		XCTAssertTrue(dates.contains(date(2026, 6, 4, 8)))
		for (earlier, later) in zip(dates, dates.dropFirst()) {
			XCTAssertGreaterThanOrEqual(later.timeIntervalSince(earlier), 3_600, "\(earlier) – \(later)")
		}
	}

	private func assertIncreasing(_ dates: [Date], after now: Date, line: UInt = #line) {
		XCTAssertGreaterThan(dates.first ?? now, now, line: line)
		for (earlier, later) in zip(dates, dates.dropFirst()) {
			XCTAssertLessThan(earlier, later, line: line)
		}
	}

	private func isMidnight(_ date: Date) -> Bool {
		calendar.startOfDay(for: date) == date
	}

	private func entryDates(_ birthday: Date, _ now: Date, limit: Int) -> [Date] {
		LockScreenSchedule.entryDates(birthday: birthday, after: now, calendar: calendar, limit: limit)
	}

	private func text(_ birthday: Date, _ now: Date) -> LockScreenText {
		LockScreenText(name: "Leo", birthday: birthday, now: now, locale: Locale(identifier: "en"), calendar: calendar)
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
