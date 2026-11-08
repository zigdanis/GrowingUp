import Core
import WidgetKit

/// The pinned people at one moment of the Home Screen timeline, or why there are none.
struct AgeEntry: TimelineEntry {
	let date: Date
	let content: WidgetLoadResult<[WidgetPerson]>

	/// The people shown, none unless they were loaded.
	var persons: [WidgetPerson] {
		content.value ?? []
	}
}

extension AgeEntry {
	/// Entries only when a tile's text can change: the next age change of any person, shown to the minute, and local
	/// midnight for birthday captions. WidgetKit reloads at the first change after the last entry, which is always in the
	/// future. A store that could not be read shows one entry and asks for an earlier retry instead.
	static func timeline(for content: WidgetLoadResult<[WidgetPerson]>, now: Date, calendar: Calendar = .current) -> Timeline<AgeEntry> {
		if case .unavailable = content {
			return Timeline(entries: [AgeEntry(date: now, content: content)], policy: .after(WidgetRetrySchedule.reloadDate(after: now)))
		}
		let birthdays = (content.value ?? []).map(\.birthday)
		let schedule = AgeTimelineSchedule(birthdays: birthdays, finestUnit: PersonTileContent.finestUnit, calendar: calendar)
		let dates = schedule.entryDates(from: now)
		let entries = dates.map { AgeEntry(date: $0, content: content) }
		return Timeline(entries: entries, policy: .after(schedule.reloadDate(after: dates, now: now)))
	}
}
