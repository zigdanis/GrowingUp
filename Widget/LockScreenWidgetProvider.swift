import Core
import WidgetKit

/// Publishes the first pinned person for the Lock Screen widgets, with an entry only where their text changes.
struct LockScreenWidgetProvider: TimelineProvider {
	/// Upcoming changes per timeline: about a week, or half a day for a newborn counting hours.
	private static let entryLimit = 14

	private let loader: WidgetPersonLoader

	init(loader: WidgetPersonLoader = .live) {
		self.loader = loader
	}

	func placeholder(in context: Context) -> LockScreenEntry {
		LockScreenEntry(date: Date(), person: Self.samplePerson())
	}

	func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
		if context.isPreview {
			completion(placeholder(in: context))
			return
		}
		Task {
			completion(LockScreenEntry(date: Date(), person: await loader.loadFirst()))
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
		Task {
			let person = await loader.loadFirst()
			let now = Date()
			let calendar = Calendar.current
			let dates = person.map { LockScreenSchedule.entryDates(birthday: $0.birthday, after: now, calendar: calendar, limit: Self.entryLimit) } ?? []
			let entries = ([now] + dates).map { LockScreenEntry(date: $0, person: person) }
			// Pinning someone in the app reloads every timeline, so an empty one only checks again the next day.
			let tomorrow = AgeTimelineSchedule(birthdays: [], calendar: calendar).nextChange(after: now)
			let reload = person.map { LockScreenSchedule.reloadDate(birthday: $0.birthday, after: dates, now: now, calendar: calendar) } ?? tomorrow
			completion(Timeline(entries: entries, policy: .after(reload)))
		}
	}

	// MARK: - Previews / placeholder

	/// Leo, five years and three months old, for the widget gallery and placeholders; previews can instead
	/// place his sixth birthday `birthdayInDays` days from now.
	static func samplePerson(birthdayInDays: Int? = nil) -> WidgetPerson {
		let age = birthdayInDays.map { DateComponents(year: -6, day: $0) } ?? DateComponents(year: -5, month: -3)
		let birthday = Calendar.current.date(byAdding: age, to: Date()) ?? Date()
		return WidgetPerson(id: UUID(), index: 0, name: String(localized: "Leo", table: "Widget"), birthday: birthday, image: nil)
	}
}
