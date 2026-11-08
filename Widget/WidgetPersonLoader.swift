import Core
import OSLog
import UIKit

/// Loads the pinned people for the widgets with their widget photos.
///
/// People follow the mosaic order, so each person's `index` matches the app's deep link. A fetch that finds nobody is a
/// confirmed absence; a failed fetch is unavailable, never an empty list. A photo that fails to load leaves that person
/// without one.
struct WidgetPersonLoader {
	/// Names only the error's domain and code: never a person's name, birthday or photo.
	private static let logger = Logger(subsystem: "pro.ziganshin.GrowingUp", category: "Widget")

	let fetch: () async throws -> [Person]
	let loadImage: (PersonImage) async throws -> UIImage

	/// Reads the shared App Group store and image cache, as the widget extension does.
	static var live: WidgetPersonLoader {
		let gateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		let useCase = FetchPersonsUseCaseImplementation(personsGateway: gateway)
		return WidgetPersonLoader(
			fetch: { try await useCase.fetchWidgetPersons() },
			loadImage: { try await ImagesCache.loadWidgetImage(image: $0) })
	}

	/// The first `limit` pinned people.
	func load(limit: Int) async -> WidgetLoadResult<[WidgetPerson]> {
		let people: [Person]
		do {
			people = try await fetch().sorted()
		} catch {
			let cause = Self.cause(of: error)
			Self.logger.error("Pinned people unavailable: \(cause.domain, privacy: .public) \(cause.code, privacy: .public)")
			return .unavailable
		}
		guard !people.isEmpty else { return .nobodyPinned }
		var persons = [WidgetPerson]()
		for (index, person) in people.prefix(limit).enumerated() {
			var image: UIImage?
			if let personImage = PersonImage(id: person.widgetPicId) {
				image = try? await loadImage(personImage)
			}
			persons.append(WidgetPerson(id: person.id, index: index, name: person.name, birthday: person.birthday, image: image))
		}
		return .loaded(persons)
	}

	/// The first pinned person, shown by the Lock Screen widget.
	func loadFirst() async -> WidgetLoadResult<WidgetPerson> {
		await load(limit: 1).map { $0[0] }
	}

	/// The error's domain and code, or those of the error a `CoreError` wraps; its message can quote a stored value.
	private static func cause(of error: Error) -> (domain: String, code: Int) {
		if let error = error as? CoreError {
			return (error.underlyingDomain ?? "CoreError", error.underlyingCode ?? 0)
		}
		let error = error as NSError
		return (error.domain, error.code)
	}
}
