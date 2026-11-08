import Core
import WidgetKit

/// The first pinned person at one moment of the Lock Screen timeline, or why there is nobody.
struct LockScreenEntry: TimelineEntry {
	let date: Date
	let content: WidgetLoadResult<WidgetPerson>
}

extension LockScreenEntry {
	/// Upcoming changes per timeline: about a week, or half a day for a newborn counting hours.
	static let entryLimit = 14

	/// An entry only where the person's text changes. Pinning someone in the app reloads every timeline, so a confirmed
	/// empty one only checks again the next day; a store that could not be read asks for an earlier retry.
	static func timeline(for content: WidgetLoadResult<WidgetPerson>, now: Date, calendar: Calendar = .current) -> Timeline<LockScreenEntry> {
		let reload: Date
		var dates: [Date] = []
		switch content {
		case .loaded(let person):
			dates = LockScreenSchedule.entryDates(birthday: person.birthday, after: now, calendar: calendar, limit: entryLimit)
			reload = LockScreenSchedule.reloadDate(birthday: person.birthday, after: dates, now: now, calendar: calendar)
		case .nobodyPinned:
			reload = AgeTimelineSchedule(birthdays: [], calendar: calendar).nextChange(after: now)
		case .unavailable:
			reload = WidgetRetrySchedule.reloadDate(after: now)
		}
		let entries = ([now] + dates).map { LockScreenEntry(date: $0, content: content) }
		return Timeline(entries: entries, policy: .after(reload))
	}
}
