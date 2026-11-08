//
//  AgeWidgetProvider.swift
//  Widget
//
//  WidgetKit timeline provider that surfaces the pinned people and their
//  milestone ages, reusing the Core framework (Core Data + Disk image cache)
//  over the shared App Group container.
//

import Core
import SwiftUI
import UIKit
import WidgetKit

struct AgeWidgetProvider: TimelineProvider {

	func placeholder(in context: Context) -> AgeEntry {
		AgeEntry(date: Date(), content: .loaded(Self.samplePersons()))
	}

	func getSnapshot(in context: Context, completion: @escaping (AgeEntry) -> Void) {
		if context.isPreview {
			completion(placeholder(in: context))
			return
		}
		Task {
			completion(AgeEntry(date: Date(), content: await loadPersons(family: context.family)))
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<AgeEntry>) -> Void) {
		Task {
			let content = await loadPersons(family: context.family)
			completion(AgeEntry.timeline(for: content, now: Date()))
		}
	}

	// MARK: - Data

	/// Fetches the pinned people (in mosaic order, matching the app's
	/// deep-link indexing) and loads their widget images from the shared cache.
	private func loadPersons(family: WidgetFamily) async -> WidgetLoadResult<[WidgetPerson]> {
		await WidgetPersonLoader.live.load(limit: personLimit(for: family))
	}

	private func personLimit(for family: WidgetFamily) -> Int {
		switch family {
		case .systemSmall: 1
		case .systemMedium: 3
		default: Constants.widgetPeopleLimit
		}
	}

	// MARK: - Previews / placeholder

	/// Gallery people whose ages show each kind of tile: years, months, a newborn and birthday captions.
	private static func samplePersons() -> [WidgetPerson] {
		let now = Date()
		let ages: [(String, DateComponents)] = [
			(String(localized: "Alice", table: "Widget"), DateComponents(year: -5, month: -3, day: -12)),
			(String(localized: "Boris", table: "Widget"), DateComponents(month: -11, day: -4)),
			(String(localized: "Clara", table: "Widget"), DateComponents(day: -2, hour: -4)),
			(String(localized: "Daria", table: "Widget"), DateComponents(year: -8)),
			(String(localized: "Evan", table: "Widget"), DateComponents(year: -4, day: 3)),
			(String(localized: "Farah", table: "Widget"), DateComponents(year: -30, month: -5))
		]
		return ages.enumerated().map { index, sample in
			let birthday = Calendar.current.date(byAdding: sample.1, to: now) ?? now
			return WidgetPerson(id: UUID(), index: index, name: sample.0, birthday: birthday, image: nil)
		}
	}
}
