import Core
import Observation
import UIKit

@MainActor
@Observable
final class OverviewPresenter {
	private(set) var image: UIImage?
	private(set) var age = ""
	private(set) var birthdayStatus: BirthdayStatus?
	private(set) var celebrationID = 0
	private var wasCelebrating = false
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

	func tick(person: Person, now: Date, isSelected: Bool = false) {
		let status = BirthdayStatus(birthday: person.birthday, now: now)
		// A visible birthday starts a new celebration on every page arrival, at midnight, and when the person's
		// celebrations are turned back on. People who opted out keep the indicator but get no confetti.
		let isCelebrating = isSelected && status.isToday && person.celebratesBirthdays
		if isCelebrating, !wasCelebrating {
			celebrationID += 1
		}
		wasCelebrating = isCelebrating
		birthdayStatus = status
		age = AgeCalculator.ageString(for: person.dateComponents(at: now))
	}
}
