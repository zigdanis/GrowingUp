import Core
import Observation
import UIKit

@MainActor
@Observable
final class OverviewPresenter {
	private(set) var image: UIImage?
	private(set) var age = ""
	var error: SceneError?
	private let loadImage: (PersonImage) async throws -> UIImage

	init(loadImage: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadImageFromDiskOrMemory) {
		self.loadImage = loadImage
	}

	func load(person: Person) async {
		image = nil
		guard let picture = PersonImage(id: person.appPicId) else { return }
		do {
			let loaded = try await loadImage(picture)
			try Task.checkCancellation()
			image = loaded
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
		}
	}

	func tick(person: Person, now: Date) {
		age = AgeCalculator.ageString(for: person.dateComponents(at: now))
	}
}
