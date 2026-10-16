import Core
import Observation
import UIKit

/// Loads the small circular avatars of the people strip, once per picture, preferring the widget photo to the app photo.
@MainActor
@Observable
final class AvatarThumbnailsPresenter {
	/// Downscaled pictures keyed by picture ID, so an edited photo loads again while unchanged ones stay cached.
	private(set) var thumbnails: [UUID: UIImage] = [:]
	@ObservationIgnored private var failedPictures: Set<UUID> = []
	private let loadImage: (PersonImage) async throws -> UIImage
	private let pixelSide: CGFloat

	/// `pixelSide` is the shorter side kept in pixels, enough for a selected avatar on a 3x screen.
	init(loadImage: @escaping (PersonImage) async throws -> UIImage, pixelSide: CGFloat = 132) {
		self.loadImage = loadImage
		self.pixelSide = pixelSide
	}

	func thumbnail(for person: Person) -> UIImage? {
		Self.pictureIDs(of: person).lazy.compactMap { self.thumbnails[$0] }.first
	}

	/// Loads the missing thumbnails of `persons` and drops those no longer referenced; a person without a loadable
	/// picture keeps the initial-letter placeholder.
	func load(_ persons: [Person]) async {
		let referenced = Set(persons.flatMap { Self.pictureIDs(of: $0) })
		thumbnails = thumbnails.filter { referenced.contains($0.key) }
		for person in persons {
			// Walks the pictures from the preferred one down; a cached fallback must not hide a new preferred picture.
			for id in Self.pictureIDs(of: person) where !failedPictures.contains(id) {
				if thumbnails[id] != nil { break }
				do {
					let image = try await loadImage(PersonImage(id: id, uiImage: nil))
					try Task.checkCancellation()
					let thumbnail = await downsized(image)
					try Task.checkCancellation()
					thumbnails[id] = thumbnail
					break
				} catch is CancellationError {
					return
				} catch {
					failedPictures.insert(id)
				}
			}
		}
	}

	private func downsized(_ image: UIImage) async -> UIImage {
		let shorterSide = min(image.size.width, image.size.height) * image.scale
		guard shorterSide > pixelSide else { return image }
		let ratio = pixelSide / shorterSide
		let size = CGSize(width: image.size.width * image.scale * ratio, height: image.size.height * image.scale * ratio)
		return await image.byPreparingThumbnail(ofSize: size) ?? image
	}

	private static func pictureIDs(of person: Person) -> [UUID] {
		[person.widgetPicId, person.appPicId].compactMap { $0 }
	}
}
