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

	private var fetchUseCase: FetchPersonsUseCase {
		let gateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		return FetchPersonsUseCaseImplementation(personsGateway: gateway)
	}

	func placeholder(in context: Context) -> AgeEntry {
		AgeEntry(date: Date(), persons: Self.samplePersons())
	}

	func getSnapshot(in context: Context, completion: @escaping (AgeEntry) -> Void) {
		if context.isPreview {
			completion(AgeEntry(date: Date(), persons: Self.samplePersons()))
			return
		}
		Task {
			completion(AgeEntry(date: Date(), persons: await loadPersons(family: context.family)))
		}
	}

	/// Adds entries only when a tile's text can change: the next age change of any person, shown to the minute,
	/// and local midnight for birthday captions. WidgetKit reloads after the last entry, at most 60 entries or a day ahead.
	func getTimeline(in context: Context, completion: @escaping (Timeline<AgeEntry>) -> Void) {
		Task {
			let persons = await loadPersons(family: context.family)
			let now = Date()
			let schedule = AgeTimelineSchedule(birthdays: persons.map(\.birthday), finestUnit: PersonTileContent.finestUnit)
			let entries = schedule.entryDates(from: now).map { AgeEntry(date: $0, persons: persons) }
			completion(Timeline(entries: entries, policy: .after(entries.last?.date ?? now)))
		}
	}

	// MARK: - Data

	/// Fetches the pinned people (sorted by `createdDate`, matching the app's
	/// deep-link indexing) and loads their widget images from the shared cache.
	private func loadPersons(family: WidgetFamily) async -> [WidgetPerson] {
		do {
			let people = try await fetchUseCase.fetchWidgetPersons()
			return await resolveImages(for: Array(people.prefix(personLimit(for: family))))
		} catch {
			Logging.logError(CoreError(error: error))
			return []
		}
	}

	private func personLimit(for family: WidgetFamily) -> Int {
		switch family {
		case .systemSmall: 1
		case .systemMedium: 3
		default: Constants.widgetPeopleLimit
		}
	}

	private func resolveImages(for people: [Person]) async -> [WidgetPerson] {
		var resolved = [WidgetPerson]()
		for (index, person) in people.enumerated() {
			var image: UIImage?
			if let personImage = PersonImage(id: person.widgetPicId) {
				image = try? await ImagesCache.loadWidgetImage(image: personImage)
			}
			resolved.append(
				WidgetPerson(
					id: person.id,
					index: index,
					name: person.name,
					birthday: person.birthday,
					image: image))
		}
		return resolved
	}

	// MARK: - Previews / placeholder

	/// Gallery people whose ages show each kind of tile: years, months, a newborn and birthday captions.
	private static func samplePersons() -> [WidgetPerson] {
		let now = Date()
		let ages: [(String, DateComponents)] = [
			("Alice", DateComponents(year: -5, month: -3, day: -12)),
			("Boris", DateComponents(month: -11, day: -4)),
			("Clara", DateComponents(day: -2, hour: -4)),
			("Daria", DateComponents(year: -8)),
			("Evan", DateComponents(year: -4, day: 3)),
			("Farah", DateComponents(year: -30, month: -5))
		]
		return ages.enumerated().map { index, sample in
			let birthday = Calendar.current.date(byAdding: sample.1, to: now) ?? now
			return WidgetPerson(id: UUID(), index: index, name: sample.0, birthday: birthday, image: nil)
		}
	}
}
