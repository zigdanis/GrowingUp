import Core
import WidgetKit
import XCTest

@testable import GrowingUp

final class WidgetTimelineTests: XCTestCase {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	/// 15 September 2025 at 20:30, an ordinary evening for an adult born on 3 June 2020.
	private var now: Date { date(2025, 9, 15, 20, 30) }
	private var adult: WidgetPerson {
		WidgetPerson(id: UUID(), index: 0, name: "Adult", birthday: date(2020, 6, 3, 8), image: nil)
	}

	func testUnavailableHomeWidgetRetriesWithinMinutesInsteadOfDays() {
		let timeline = AgeEntry.timeline(for: .unavailable, now: now, calendar: calendar)
		XCTAssertEqual(timeline.entries.map(\.date), [now])
		XCTAssertTrue(timeline.entries.allSatisfy(\.persons.isEmpty))
		XCTAssertEqual(timeline.policy, .after(now.addingTimeInterval(15 * 60)))
	}

	func testUnavailableLockScreenRetriesWithinMinutesInsteadOfTomorrow() {
		let timeline = LockScreenEntry.timeline(for: .unavailable, now: now, calendar: calendar)
		XCTAssertEqual(timeline.entries.map(\.date), [now])
		XCTAssertEqual(timeline.policy, .after(now.addingTimeInterval(15 * 60)))
	}

	/// Pinning someone in the app reloads every timeline, so a confirmed empty widget keeps its daily schedule.
	func testNobodyPinnedKeepsTheRegularSchedule() {
		let home = AgeEntry.timeline(for: .nobodyPinned, now: now, calendar: calendar)
		XCTAssertEqual(home.entries.map(\.date), [now, date(2025, 9, 16)])
		XCTAssertEqual(home.policy, .after(date(2025, 9, 17)))
		let lockScreen = LockScreenEntry.timeline(for: .nobodyPinned, now: now, calendar: calendar)
		XCTAssertEqual(lockScreen.entries.map(\.date), [now])
		XCTAssertEqual(lockScreen.policy, .after(date(2025, 9, 16)))
	}

	/// The first successful load after a failure returns to the age schedule, without the retry interval.
	func testLoadAfterFailureReturnsToTheAgeSchedule() {
		let person = adult
		let home = AgeEntry.timeline(for: .loaded([person]), now: now, calendar: calendar)
		XCTAssertEqual(home.entries.map(\.date), [now, date(2025, 9, 16)])
		XCTAssertEqual(home.entries.last?.persons.map(\.id), [person.id])
		XCTAssertEqual(home.policy, .after(date(2025, 9, 17)))
		let lockScreen = LockScreenEntry.timeline(for: .loaded(person), now: now, calendar: calendar)
		let dates = LockScreenSchedule.entryDates(birthday: person.birthday, after: now, calendar: calendar, limit: LockScreenEntry.entryLimit)
		XCTAssertEqual(lockScreen.entries.map(\.date), [now] + dates)
		XCTAssertEqual(lockScreen.entries.last?.content.value?.id, person.id)
		XCTAssertEqual(
			lockScreen.policy, .after(LockScreenSchedule.reloadDate(birthday: person.birthday, after: dates, now: now, calendar: calendar)))
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
