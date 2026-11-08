import Core
import WidgetKit

/// Publishes the first pinned person for the Lock Screen widgets, with an entry only where their text changes.
struct LockScreenWidgetProvider: TimelineProvider {
	private let loader: WidgetPersonLoader

	init(loader: WidgetPersonLoader = .live) {
		self.loader = loader
	}

	func placeholder(in context: Context) -> LockScreenEntry {
		LockScreenEntry(date: Date(), content: .loaded(Self.samplePerson()))
	}

	func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
		if context.isPreview {
			completion(placeholder(in: context))
			return
		}
		Task {
			completion(LockScreenEntry(date: Date(), content: await loader.loadFirst()))
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
		Task {
			completion(LockScreenEntry.timeline(for: await loader.loadFirst(), now: Date()))
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
