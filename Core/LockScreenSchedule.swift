import Foundation

/// The Lock Screen's timeline policy over `AgeTimelineSchedule`: when `LockScreenText` reads differently for one person.
public enum LockScreenSchedule {
	/// How far ahead one Lock Screen timeline reaches before WidgetKit asks for the next.
	public static let horizon: TimeInterval = 7 * 86_400

	/// The moments strictly after `now`, at most `limit` of them and at most `horizon` ahead, at which the Lock Screen
	/// changes: every local midnight, when the birthday countdown and the ring move on, and every age change it shows.
	///
	/// The Lock Screen counts hours during the first day of life and days afterwards, so a newborn's timeline ends when
	/// they turn one day old and the next one continues in days. Birthdays start at midnight, so the next birthday is
	/// among the dates once it is within reach. A midnight and an age change can be less than an hour apart when someone
	/// was born just after midnight.
	public static func entryDates(birthday: Date, after now: Date, calendar: Calendar = .current, limit: Int) -> [Date] {
		let finestUnit = LockScreenText.finestUnit(birthday: birthday, now: now, calendar: calendar)
		var reach = horizon
		if finestUnit < .days, let oneDayOld = calendar.date(byAdding: .day, value: 1, to: birthday), oneDayOld > now {
			reach = oneDayOld.timeIntervalSince(now)
		}
		let schedule = AgeTimelineSchedule(birthdays: [birthday], finestUnit: finestUnit, calendar: calendar)
		// The schedule starts with `now` itself, which the caller's first entry already covers.
		return Array(schedule.entryDates(from: now, limit: limit + 1, horizon: reach).dropFirst())
	}

	/// When a timeline whose entries are `now` followed by `entries` should reload: the first Lock Screen change after its
	/// last entry, which is a later one than the last entry itself.
	public static func reloadDate(birthday: Date, after entries: [Date], now: Date, calendar: Calendar = .current) -> Date {
		let finestUnit = LockScreenText.finestUnit(birthday: birthday, now: entries.last ?? now, calendar: calendar)
		return AgeTimelineSchedule(birthdays: [birthday], finestUnit: finestUnit, calendar: calendar).reloadDate(after: entries, now: now)
	}
}
