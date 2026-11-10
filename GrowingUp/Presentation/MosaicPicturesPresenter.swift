import Core
import Observation
import UIKit

/// Loads the pictures of the mosaic tiles once per picture as small thumbnails, choosing them by
/// `PersonPictureCandidates` like the viewer, and measures each one's average colour for the ambient background.
///
/// A picture that fails to load leaves its tile to the next candidate or the monogram, and is not asked for again until
/// `retryFailedPictures()`, at most `maxAttempts` times in all, so one that is gone for good costs only a few requests.
///
/// The first load of a launch is reported once it completes; see `MosaicPicturesLoadReport`.
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
	/// How the first load of the launch goes, reported once it completes.
	@ObservationIgnored private var report = MosaicPicturesLoadReport()
	private let loadThumbnail: (PersonImage, Int) async throws -> TileThumbnail
	private let maxPixelSize: Int
	private let maxAttempts: Int
	private let analytics: AnalyticsGateway
	private let uptime: () -> TimeInterval

	/// - Parameters:
	///   - loadThumbnail: a stored picture's thumbnail whose longer side is at most the given pixels, without keeping the
	///     full-size picture in memory, and whether it came ready from the thumbnail cache.
	///   - maxPixelSize: the longer side kept in pixels, enough for a portrait photo to fill a phone tile on a 3x screen.
	///   - maxAttempts: how many times a picture that keeps failing is asked for before its tile keeps the fallback.
	///   - analytics: receives how the launch's first load went.
	///   - uptime: a monotonic clock in seconds, which times that load.
	init(
		loadThumbnail: @escaping (PersonImage, Int) async throws -> TileThumbnail, maxPixelSize: Int = 960, maxAttempts: Int = 3,
		analytics: AnalyticsGateway = NoopAnalyticsGateway(), uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
	) {
		self.loadThumbnail = loadThumbnail
		self.maxPixelSize = maxPixelSize
		self.maxAttempts = maxAttempts
		self.analytics = analytics
		self.uptime = uptime
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
		report.begin(persons, at: uptime())
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
				let (picture, isFromCache) = try await loadPicture(of: person, from: candidates, cached: pictures[person.id])
				guard generation == self.generation, !Task.isCancelled else { return }
				pictures[person.id] = picture
				if let isFromCache { report.record(picture, isFromCache: isFromCache, for: person.id) }
			} catch {
				return
			}
		}
		if let event = report.finish(persons, at: uptime()) { analytics.track(event) }
	}

	/// Gives the failed pictures of the latest load another try, unless they failed `maxAttempts` times, such as when the
	/// app returns to the foreground after a read failed while the device was locked; a picture that loads now replaces
	/// its tile's fallback.
	///
	/// The retry runs to its end even when the caller is cancelled, as when the app leaves the foreground again: it
	/// supersedes the load before it, which would otherwise leave tiles without their pictures.
	func retryFailedPictures() async {
		await Task { await self.loadRetriedPictures() }.value
	}

	/// Takes the people only once the retry runs, so a newer load that came meanwhile is never superseded by older ones.
	private func loadRetriedPictures() async {
		let retried = failedPictures.filter { failures[$0, default: 0] < maxAttempts }
		guard !retried.isEmpty else { return }
		failedPictures.subtract(retried)
		await load(listed)
	}

	/// The first of `candidates` that loads, or the monogram, with whether it came from the thumbnail cache; throws only
	/// when cancelled.
	///
	/// A candidate the tile already shows as its `cached` photo is kept rather than read again, so a preferred photo that
	/// fails once more on a retry leaves the fallback photo in place instead of the monogram; it was not read now, so
	/// `isFromCache` is nil.
	private func loadPicture(
		of person: Person, from candidates: [UUID], cached: MosaicPicture?
	) async throws -> (picture: MosaicPicture, isFromCache: Bool?) {
		for id in candidates {
			if let cached, cached.pictureID == id { return (cached, nil) }
			do {
				let thumbnail = try await loadThumbnail(PersonImage(id: id, uiImage: nil), maxPixelSize)
				try Task.checkCancellation()
				failures[id] = nil
				let image = thumbnail.image
				let picture = MosaicPicture(pictureID: id, name: person.name, image: image, averageColor: await Self.averageColor(of: image))
				return (picture, thumbnail.isFromCache)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				failures[id, default: 0] += 1
				failedPictures.insert(id)
			}
		}
		// In the tile's portrait shape, so the initial stays whole in its corner as on the person's page.
		let monogram = MonogramPicture.draw(id: person.id, name: person.name, size: CGSize(width: maxPixelSize * 9 / 16, height: maxPixelSize))
		return (MosaicPicture(pictureID: nil, name: person.name, image: monogram, averageColor: await Self.averageColor(of: monogram)), false)
	}

	/// Measures off the main actor, so loading many tiles never stalls scrolling.
	private nonisolated static func averageColor(of image: UIImage) async -> UIColor? {
		image.averageColor
	}
}
