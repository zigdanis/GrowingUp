import Core
import Observation
import UIKit

/// Loads the pictures of the mosaic tiles once per picture, preferring the portrait app photo to the square widget photo,
/// and measures each one's average colour for the ambient background.
@MainActor
@Observable
final class MosaicPicturesPresenter {
	/// The tile pictures keyed by person ID.
	private(set) var pictures: [UUID: MosaicPicture] = [:]
	@ObservationIgnored private var failedPictures: Set<UUID> = []
	private let loadImage: (PersonImage) async throws -> UIImage
	private let pixelSide: CGFloat

	/// `pixelSide` is the shorter side kept in pixels, enough for the widest tile on a 3x screen.
	init(loadImage: @escaping (PersonImage) async throws -> UIImage, pixelSide: CGFloat = 600) {
		self.loadImage = loadImage
		self.pixelSide = pixelSide
	}

	/// The tile picture of `person`; nil while it loads.
	func picture(for person: Person) -> MosaicPicture? { pictures[person.id] }

	/// The average colours of the first four people with a loaded picture, in mosaic order.
	func ambientSeeds(for persons: [Person]) -> [UIColor] {
		Array(persons.lazy.compactMap { self.pictures[$0.id]?.averageColor }.prefix(4))
	}

	/// Loads the missing or outdated pictures of `persons` and drops those of people no longer listed; a person without a
	/// loadable photo gets their monogram.
	func load(_ persons: [Person]) async {
		let listed = Set(persons.map(\.id))
		pictures = pictures.filter { listed.contains($0.key) }
		for person in persons {
			// A cached fallback must not hide a new preferred picture, and a renamed person needs a new monogram.
			let candidates = Self.pictureIDs(of: person).filter { !failedPictures.contains($0) }
			if let current = pictures[person.id], current.pictureID == candidates.first, current.pictureID != nil || current.name == person.name {
				continue
			}
			do {
				pictures[person.id] = try await loadPicture(of: person, from: candidates)
			} catch {
				return
			}
		}
	}

	/// The first of `candidates` that loads, or the monogram; throws only when cancelled.
	private func loadPicture(of person: Person, from candidates: [UUID]) async throws -> MosaicPicture {
		for id in candidates {
			do {
				let image = try await loadImage(PersonImage(id: id, uiImage: nil))
				try Task.checkCancellation()
				let thumbnail = await downsized(image)
				try Task.checkCancellation()
				return MosaicPicture(pictureID: id, name: person.name, image: thumbnail, averageColor: await Self.averageColor(of: thumbnail))
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				failedPictures.insert(id)
			}
		}
		let monogram = MonogramPicture.draw(id: person.id, name: person.name)
		return MosaicPicture(pictureID: nil, name: person.name, image: monogram, averageColor: await Self.averageColor(of: monogram))
	}

	private func downsized(_ image: UIImage) async -> UIImage {
		let shorterSide = min(image.size.width, image.size.height) * image.scale
		guard shorterSide > pixelSide else { return image }
		let ratio = pixelSide / shorterSide
		let size = CGSize(width: image.size.width * image.scale * ratio, height: image.size.height * image.scale * ratio)
		return await image.byPreparingThumbnail(ofSize: size) ?? image
	}

	/// Measures off the main actor, so loading many tiles never stalls scrolling.
	private nonisolated static func averageColor(of image: UIImage) async -> UIColor? {
		image.averageColor
	}

	private static func pictureIDs(of person: Person) -> [UUID] {
		[person.appPicId, person.widgetPicId].compactMap { $0 }
	}
}
