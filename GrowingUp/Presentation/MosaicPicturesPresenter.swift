import Core
import Observation
import UIKit

/// Loads the pictures of the mosaic tiles once per picture as small thumbnails, choosing them by
/// `PersonPictureCandidates` like the viewer, and measures each one's average colour for the ambient background.
///
/// A picture that fails to load leaves its tile to the next candidate or the monogram, and is not asked for again until
/// `retryFailedPictures()`, at most `maxAttempts` times in all, so one that is gone for good costs only a few requests.
@MainActor
@Observable
final class MosaicPicturesPresenter {
	/// The tile pictures keyed by person ID.
	private(set) var pictures: [UUID: MosaicPicture] = [:]
	/// The number of failed loads of each picture that has not loaded since.
	@ObservationIgnored private var failures: [UUID: Int] = [:]
	/// The failed pictures left out of loads until the next `retryFailedPictures()`.
	@ObservationIgnored private var failedPictures: Set<UUID> = []
	/// The people of the latest load, whose failed pictures a retry loads again.
	@ObservationIgnored private var listed: [Person] = []
	/// Counts the loads, so one that a newer load superseded never publishes over the newer pictures.
	@ObservationIgnored private var generation = 0
	private let loadThumbnail: (PersonImage, Int) async throws -> UIImage
	private let maxPixelSize: Int
	private let maxAttempts: Int

	/// - Parameters:
	///   - loadThumbnail: decodes a stored picture to a thumbnail whose longer side is at most the given pixels, without
	///     keeping the full-size picture in memory.
	///   - maxPixelSize: the longer side kept in pixels, enough for a portrait photo to fill a phone tile on a 3x screen.
	///   - maxAttempts: how many times a picture that keeps failing is asked for before its tile keeps the fallback.
	init(loadThumbnail: @escaping (PersonImage, Int) async throws -> UIImage, maxPixelSize: Int = 960, maxAttempts: Int = 3) {
		self.loadThumbnail = loadThumbnail
		self.maxPixelSize = maxPixelSize
		self.maxAttempts = maxAttempts
	}

	/// The tile picture of `person`; nil while it loads.
	func picture(for person: Person) -> MosaicPicture? { pictures[person.id] }

	/// The average colours of the first four people with a loaded picture, in mosaic order.
	func ambientSeeds(for persons: [Person]) -> [UIColor] {
		Array(persons.lazy.compactMap { self.pictures[$0.id]?.averageColor }.prefix(4))
	}

	/// Loads the missing or outdated pictures of `persons` and drops those of people no longer listed; a person without a
	/// loadable photo gets their monogram.
	///
	/// A newer load supersedes this one: from then on this one publishes nothing, so an older photo, monogram or removed
	/// person never comes back over the newer ones.
	func load(_ persons: [Person]) async {
		generation += 1
		let generation = generation
		self.listed = persons
		let listed = Set(persons.map(\.id))
		pictures = pictures.filter { listed.contains($0.key) }
		for person in persons {
			// A cached fallback must not hide a new preferred picture, and a renamed person needs a new monogram.
			let candidates = PersonPictureCandidates.ids(of: person).filter { !failedPictures.contains($0) }
			if let current = pictures[person.id], current.pictureID == candidates.first, current.pictureID != nil || current.name == person.name {
				continue
			}
			do {
				let picture = try await loadPicture(of: person, from: candidates)
				guard generation == self.generation, !Task.isCancelled else { return }
				pictures[person.id] = picture
			} catch {
				return
			}
		}
	}

	/// Gives the failed pictures of the latest load another try, unless they failed `maxAttempts` times, such as when the
	/// app returns to the foreground after a read failed while the device was locked; a picture that loads now replaces
	/// its tile's fallback.
	///
	/// The retry runs to its end even when the caller is cancelled, as when the app leaves the foreground again: it
	/// supersedes the load before it, which would otherwise leave tiles without their pictures.
	func retryFailedPictures() async {
		let retried = failedPictures.filter { failures[$0, default: 0] < maxAttempts }
		guard !retried.isEmpty else { return }
		failedPictures.subtract(retried)
		let persons = listed
		await Task { await load(persons) }.value
	}

	/// The first of `candidates` that loads, or the monogram; throws only when cancelled.
	private func loadPicture(of person: Person, from candidates: [UUID]) async throws -> MosaicPicture {
		for id in candidates {
			do {
				let thumbnail = try await loadThumbnail(PersonImage(id: id, uiImage: nil), maxPixelSize)
				try Task.checkCancellation()
				failures[id] = nil
				return MosaicPicture(pictureID: id, name: person.name, image: thumbnail, averageColor: await Self.averageColor(of: thumbnail))
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				failures[id, default: 0] += 1
				failedPictures.insert(id)
			}
		}
		// In the tile's portrait shape, so the initial stays whole in its corner as on the person's page.
		let monogram = MonogramPicture.draw(id: person.id, name: person.name, size: CGSize(width: maxPixelSize * 9 / 16, height: maxPixelSize))
		return MosaicPicture(pictureID: nil, name: person.name, image: monogram, averageColor: await Self.averageColor(of: monogram))
	}

	/// Measures off the main actor, so loading many tiles never stalls scrolling.
	private nonisolated static func averageColor(of image: UIImage) async -> UIColor? {
		image.averageColor
	}
}
