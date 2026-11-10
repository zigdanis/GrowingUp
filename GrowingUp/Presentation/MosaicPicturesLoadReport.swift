import Core
import Foundation

/// Follows the first load of the mosaic's pictures on a launch into one `mosaicPicturesLoaded` event, which shows how
/// long people look at grey tiles and how often the thumbnail cache spares the decoding.
///
/// The clock starts with the first load of a non-empty list: at launch the mosaic first loads no one, while the people
/// are still read. A load that a newer one supersedes or that is cancelled keeps its tiles and the clock running, so the
/// load that completes reports the whole wait; the loads after the report, for edits and retries, report nothing.
struct MosaicPicturesLoadReport {
	/// When the first non-empty load began, in seconds of a monotonic clock.
	private var start: TimeInterval?
	private var isReported = false
	/// Whether each tile's photo came from the thumbnail cache, keyed by person ID; a monogram tile has no entry.
	private var photos: [UUID: Bool] = [:]

	/// A load of `persons` begins at `time`.
	mutating func begin(_ persons: [Person], at time: TimeInterval) {
		guard !isReported, start == nil, !persons.isEmpty else { return }
		start = time
	}

	/// The tile of `person` now shows `picture`, read from the thumbnail cache or decoded from the full-size picture.
	mutating func record(_ picture: MosaicPicture, isFromCache: Bool, for person: UUID) {
		guard !isReported, start != nil else { return }
		photos[person] = picture.pictureID == nil ? nil : isFromCache
	}

	/// The event for a load of `persons` that ran to its end at `time`; nil unless it is the first to do so since the clock
	/// started.
	mutating func finish(_ persons: [Person], at time: TimeInterval) -> AnalyticsEvent? {
		guard !isReported, let start, !persons.isEmpty else { return nil }
		isReported = true
		let sources = persons.compactMap { photos[$0.id] }
		let cachedCount = sources.filter { $0 }.count
		let decodedCount = sources.count - cachedCount
		photos = [:]
		return .mosaicPicturesLoaded(
			peopleCount: persons.count, cachedCount: cachedCount, decodedCount: decodedCount,
			monogramCount: persons.count - sources.count, durationMs: Int(((time - start) * 1000).rounded()))
	}
}
