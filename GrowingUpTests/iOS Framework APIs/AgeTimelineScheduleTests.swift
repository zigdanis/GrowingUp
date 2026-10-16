import Core
import XCTest

final class AgeTimelineScheduleTests: XCTestCase {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	/// 10 January 2026 at 10:07:30.
	private var newborn: Date { date(2026, 1, 10, 10, 7).addingTimeInterval(30) }
	private var adult: Date { date(2020, 6, 3, 8) }

	func testAdultOnlyChangesAtMidnightAndOnMonthlyAnniversaries() {
		let schedule = AgeTimelineSchedule(birthdays: [adult], calendar: calendar)
		let now = date(2025, 9, 15, 20, 30)
		XCTAssertEqual(schedule.entryDates(from: now), [now, date(2025, 9, 16)])
		let beforeAnniversary = date(2025, 10, 2, 12)
		XCTAssertEqual(schedule.entryDates(from: beforeAnniversary), [beforeAnniversary, date(2025, 10, 3), date(2025, 10, 3, 8)])
	}

	func testNewbornChangesEveryMinuteUntilTheEntryLimit() {
		let schedule = AgeTimelineSchedule(birthdays: [newborn], calendar: calendar)
		let now = date(2026, 1, 10, 11, 30)
		let firstChange = now.addingTimeInterval(30)
		let expected = [now] + (0..<59).map { firstChange.addingTimeInterval(Double($0) * 60) }
		XCTAssertEqual(schedule.entryDates(from: now), expected)
		XCTAssertEqual(schedule.entryDates(from: now, horizon: 600), Array(expected.prefix(11)))
	}

	func testPeopleShareOneTimelineOfTheirEarliestChanges() {
		let now = date(2026, 1, 10, 11, 30)
		let both = AgeTimelineSchedule(birthdays: [adult, newborn], calendar: calendar).entryDates(from: now)
		XCTAssertEqual(both, AgeTimelineSchedule(birthdays: [newborn], calendar: calendar).entryDates(from: now))
		XCTAssertEqual(AgeTimelineSchedule(birthdays: [], calendar: calendar).nextChange(after: now), date(2026, 1, 11))
		let mixed = AgeTimelineSchedule(birthdays: [adult, date(2026, 1, 12, 15)], calendar: calendar).entryDates(from: date(2026, 1, 13, 23))
		XCTAssertEqual(mixed.first, date(2026, 1, 13, 23))
		XCTAssertEqual(mixed, mixed.sorted())
		XCTAssertEqual(Set(mixed).count, mixed.count, "Simultaneous changes appear once")
		XCTAssertTrue(mixed.contains(date(2026, 1, 14)))
	}

	func testEntriesAlwaysChangeTheSummaryWhenClocksGoBack() throws {
		let newYork = try newYorkCalendar()
		let birthday = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 10, day: 31)))
		// 06:00 UTC is the second 01:00 of 1 November in New York.
		let now = date(2026, 11, 1, 6)
		let entries = AgeTimelineSchedule(birthdays: [birthday], calendar: newYork).entryDates(from: now)
		XCTAssertGreaterThan(entries.count, 1)
		for (previous, next) in zip(entries, entries.dropFirst()) {
			XCTAssertGreaterThan(next, previous)
			let before = AgeSummary(birthday: birthday, now: previous, finestUnit: .minutes, calendar: newYork)
			XCTAssertNotEqual(AgeSummary(birthday: birthday, now: next, finestUnit: .minutes, calendar: newYork), before, "\(next)")
		}
	}

	func testReloadDateIsAfterTheLastEntryOnAShortHorizonDay() throws {
		let newYork = try newYorkCalendar()
		let schedule = AgeTimelineSchedule(birthdays: [adult], calendar: newYork)
		// Clocks go back on 1 November 2026, so the next midnight is 25 hours away and beyond the 24-hour horizon.
		let now = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 11, day: 1, minute: 1)))
		let entries = schedule.entryDates(from: now)
		XCTAssertEqual(entries, [now])
		let lastEntry = try XCTUnwrap(entries.last)
		let reload = schedule.reloadDate(after: entries, now: now)
		XCTAssertGreaterThan(reload, lastEntry)
		XCTAssertEqual(reload, try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 11, day: 2))))
	}

	private func newYorkCalendar() throws -> Calendar {
		var newYork = calendar
		newYork.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
		return newYork
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
