import Core
import UIKit

/// Loads the pinned people for the widgets with their widget photos.
///
/// People follow the mosaic order, so each person's `index` matches the app's deep link. A failed fetch is
/// logged and reads as nobody pinned; a photo that fails to load leaves that person without one.
struct WidgetPersonLoader {
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
	func load(limit: Int) async -> [WidgetPerson] {
		let people: [Person]
		do {
			people = try await fetch().sorted()
		} catch {
			Logging.logError(CoreError(error: error))
			return []
		}
		var persons = [WidgetPerson]()
		for (index, person) in people.prefix(limit).enumerated() {
			var image: UIImage?
			if let personImage = PersonImage(id: person.widgetPicId) {
				image = try? await loadImage(personImage)
			}
			persons.append(WidgetPerson(id: person.id, index: index, name: person.name, birthday: person.birthday, image: image))
		}
		return persons
	}

	/// The first pinned person, shown by the Lock Screen widgets.
	func loadFirst() async -> WidgetPerson? {
		await load(limit: 1).first
	}
}
