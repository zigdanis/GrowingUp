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
	private var wasSelected = false
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
		if isSelected, status.isToday, !wasSelected || birthdayStatus?.isToday != true {
			celebrationID += 1
		}
		wasSelected = isSelected
		birthdayStatus = status
		age = AgeCalculator.ageString(for: person.dateComponents(at: now))
	}
}
