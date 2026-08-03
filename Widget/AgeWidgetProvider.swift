//
//  AgeWidgetProvider.swift
//  Widget
//
//  WidgetKit timeline provider that surfaces the pinned people and their live
//  age, reusing the Core framework (Core Data + Disk image cache) over the
//  shared App Group container.
//

import Core
import SwiftUI
import UIKit
import WidgetKit

/// Max pinned people shown, matching the legacy widget and the app's limit.
let rowsLimit = 3

/// Age "ticks" at minute granularity (per-second refresh is not allowed for
/// home-screen widgets), so we publish one entry per minute.
private let entryCadence: TimeInterval = 60
/// How many minute-entries to publish before asking WidgetKit to reload.
private let entriesPerTimeline = 60

/// A single pinned person captured for rendering, with its deep-link index.
struct WidgetPerson: Identifiable {
	let id: UUID
	let index: Int
	let name: String
	let birthday: Date
	let image: UIImage?

	/// Custom-scheme URL the app already handles in `application(_:open:)`.
	var deepLinkURL: URL {
		URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=\(index)")!
	}
}

struct AgeEntry: TimelineEntry {
	let date: Date
	let persons: [WidgetPerson]
}

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
			completion(AgeEntry(date: Date(), persons: await loadPersons()))
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<AgeEntry>) -> Void) {
		Task {
			let persons = await loadPersons()
			let start = Date()
			var entries: [AgeEntry] = []
			for offset in 0..<entriesPerTimeline {
				let date = start.addingTimeInterval(Double(offset) * entryCadence)
				entries.append(AgeEntry(date: date, persons: persons))
			}
			let next = start.addingTimeInterval(Double(entriesPerTimeline) * entryCadence)
			completion(Timeline(entries: entries, policy: .after(next)))
		}
	}

	// MARK: - Data

	/// Fetches the pinned people (sorted by `createdDate`, matching the app's
	/// deep-link indexing) and loads their widget images from the shared cache.
	private func loadPersons() async -> [WidgetPerson] {
		do {
			let people = try await fetchUseCase.fetchWidgetPersons()
			return await resolveImages(for: Array(people.prefix(rowsLimit)))
		} catch {
			Logging.logError(CoreError(error: error))
			return []
		}
	}

	private func resolveImages(for people: [Person]) async -> [WidgetPerson] {
		var resolved = [WidgetPerson]()
		for (index, person) in people.enumerated() {
			var image: UIImage?
			if let personImage = PersonImage(id: person.widgetPicId) {
				image = try? await ImagesCache.loadImageFromDiskOrMemory(image: personImage)
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

	private static func samplePersons() -> [WidgetPerson] {
		let calendar = Calendar.current
		return (0..<2).map { index in
			let birthday = calendar.date(byAdding: .year, value: -(index + 1) * 3, to: Date()) ?? Date()
			return WidgetPerson(id: UUID(), index: index, name: "—", birthday: birthday, image: nil)
		}
	}
}
