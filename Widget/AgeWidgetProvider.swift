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
		loadPersons { persons in
			completion(AgeEntry(date: Date(), persons: persons))
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<AgeEntry>) -> Void) {
		loadPersons { persons in
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
	private func loadPersons(completion: @escaping ([WidgetPerson]) -> Void) {
		fetchUseCase.fetchWidgetPersons { result in
			switch result {
			case .success(let people):
				let limited = Array(people.prefix(rowsLimit))
				resolveImages(for: limited, completion: completion)
			case .failure(let error):
				Logging.logError(error)
				completion([])
			}
		}
	}

	private func resolveImages(for people: [Person], completion: @escaping ([WidgetPerson]) -> Void) {
		var widgetPersons = [WidgetPerson?](repeating: nil, count: people.count)
		let group = DispatchGroup()

		for (index, person) in people.enumerated() {
			func store(_ image: UIImage?) {
				widgetPersons[index] = WidgetPerson(
					id: person.id,
					index: index,
					name: person.name,
					birthday: person.birthday,
					image: image)
			}
			guard let personImage = PersonImage(id: person.widgetPicId) else {
				store(nil)
				continue
			}
			group.enter()
			ImagesCache.loadImageFromDiskOrMemory(image: personImage) { imageResult in
				switch imageResult {
				case .success(let image): store(image)
				case .failure: store(nil)
				}
				group.leave()
			}
		}

		group.notify(queue: .main) {
			completion(widgetPersons.compactMap { $0 })
		}
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
