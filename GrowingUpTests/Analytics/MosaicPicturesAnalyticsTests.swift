import Core
import UIKit
import XCTest

@testable import GrowingUp

/// The mosaic reports its launch's first load of tile pictures once: where each tile's picture came from and how long the
/// tiles waited, from the first load of the people to the last picture.
@MainActor
final class MosaicPicturesAnalyticsTests: XCTestCase {
	func testTheFirstLoadReportsCachedDecodedAndMonogramTilesWithItsDuration() async {
		let cached = Person.createPerson()
		let decoded = Person.createPerson()
		var noPhotos = Person.createPerson()
		noPhotos.appPicId = nil
		noPhotos.widgetPicId = nil
		let broken = Person.createPerson()
		let analytics = AnalyticsGatewaySpy()
		var now: TimeInterval = 50
		let presenter = MosaicPicturesPresenter(
			loadThumbnail: { picture, _ in
				now += 0.25
				if picture.id == broken.appPicId || picture.id == broken.widgetPicId { throw CoreError.missingValue }
				return Self.thumbnail(isFromCache: picture.id == cached.appPicId)
			}, analytics: analytics, uptime: { now })
		await presenter.load([])
		XCTAssertEqual(analytics.events, [], "Before the people are read, the mosaic loads no one and reports nothing")
		now = 100
		await presenter.load([cached, decoded, noPhotos, broken])
		XCTAssertEqual(
			analytics.events,
			[.mosaicPicturesLoaded(peopleCount: 4, cachedCount: 1, decodedCount: 1, monogramCount: 2, durationMs: 1000)],
			"Four reads of a quarter second each, timed from the first load of the people")
	}

	func testOnlyTheFirstCompletedLoadOfALaunchIsReported() async {
		var person = Person.createPerson()
		person.widgetPicId = nil
		let analytics = AnalyticsGatewaySpy()
		var fails = true
		let presenter = MosaicPicturesPresenter(
			loadThumbnail: { _, _ in
				if fails { throw CoreError.missingValue }
				return Self.thumbnail(isFromCache: false)
			}, analytics: analytics, uptime: { 0 })
		await presenter.load([person])
		fails = false
		await presenter.retryFailedPictures()
		person.appPicId = UUID()
		await presenter.load([person])
		await presenter.load([])
		XCTAssertEqual(
			analytics.events,
			[.mosaicPicturesLoaded(peopleCount: 1, cachedCount: 0, decodedCount: 0, monogramCount: 1, durationMs: 0)],
			"Retries and edits report nothing")
	}

	func testASupersededFirstLoadIsFoldedIntoTheLoadThatCompletes() async {
		let cached = Person.createPerson()
		let decoded = Person.createPerson()
		let analytics = AnalyticsGatewaySpy()
		var now: TimeInterval = 10
		var held = false
		var gate: CheckedContinuation<Void, Never>?
		let presenter = MosaicPicturesPresenter(
			loadThumbnail: { picture, _ in
				now += 1
				if picture.id == decoded.appPicId, !held {
					held = true
					await withCheckedContinuation { gate = $0 }
				}
				return Self.thumbnail(isFromCache: picture.id == cached.appPicId)
			}, analytics: analytics, uptime: { now })
		let stale = Task { await presenter.load([cached, decoded]) }
		while gate == nil { await Task.yield() }
		XCTAssertEqual(analytics.events, [])
		// The newer load keeps the cached tile the first one published and reads only the second picture.
		await presenter.load([cached, decoded])
		gate?.resume()
		await stale.value
		XCTAssertEqual(
			analytics.events,
			[.mosaicPicturesLoaded(peopleCount: 2, cachedCount: 1, decodedCount: 1, monogramCount: 0, durationMs: 3000)],
			"The whole wait, from the first load's start")
	}

	private static func thumbnail(isFromCache: Bool) -> TileThumbnail {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).image { context in
			UIColor.systemTeal.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
		}
		return TileThumbnail(image: image, isFromCache: isFromCache)
	}
}
