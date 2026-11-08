import Core
import UIKit
import XCTest

@testable import GrowingUp

/// A tile picture that failed to load gets another try on `retryFailedPictures()`, such as on return to the app, a
/// bounded number of times, with the monogram as the quiet fallback meanwhile.
@MainActor
final class MosaicPicturesRetryTests: XCTestCase {
	func testAPictureThatFailedOnceLoadsAgainOnRetryWithTheSameID() async throws {
		var person = Person.createPerson()
		person.widgetPicId = nil
		let photo = try XCTUnwrap(person.appPicId)
		var requests: [UUID?] = []
		var fails = true
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, _ in
			requests.append(picture.id)
			if fails { throw CoreError.missingValue }
			return Self.photo(.systemTeal)
		})
		await presenter.load([person])
		XCTAssertNil(presenter.picture(for: person)?.pictureID, "The monogram stands in quietly")
		await presenter.load([person])
		XCTAssertEqual(requests, [photo], "Not asked for again until a retry")
		fails = false
		await presenter.retryFailedPictures()
		XCTAssertEqual(requests, [photo, photo])
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, photo)
		await presenter.retryFailedPictures()
		XCTAssertEqual(requests.count, 2, "A loaded picture needs no retry")
	}

	func testAPictureThatKeepsFailingIsAskedForOnlyABoundedNumberOfTimes() async {
		var person = Person.createPerson()
		person.widgetPicId = nil
		var requests = 0
		let presenter = MosaicPicturesPresenter(
			loadThumbnail: { _, _ in
				requests += 1
				throw CoreError.missingValue
			}, maxAttempts: 3)
		await presenter.load([person])
		for _ in 0..<5 { await presenter.retryFailedPictures() }
		XCTAssertEqual(requests, 3)
		XCTAssertNil(presenter.picture(for: person)?.pictureID)
		XCTAssertNotNil(presenter.picture(for: person), "The monogram stays")
	}

	func testACancelledPictureIsNoFailureAndARetryOutlivesItsCancelledCaller() async {
		var person = Person.createPerson()
		person.widgetPicId = nil
		var gate: CheckedContinuation<Void, Never>?
		var requests = 0
		var fails = true
		let presenter = MosaicPicturesPresenter(loadThumbnail: { _, _ in
			requests += 1
			if fails { throw CoreError.missingValue }
			await withCheckedContinuation { gate = $0 }
			return Self.photo(.systemTeal)
		})
		await presenter.load([person])
		fails = false
		// The app leaves the foreground again while the retry still loads.
		let retry = Task { await presenter.retryFailedPictures() }
		while gate == nil { await Task.yield() }
		retry.cancel()
		gate?.resume()
		await retry.value
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, person.appPicId)

		let other = Person.createPerson()
		gate = nil
		let cancelled = Task { await presenter.load([other]) }
		while gate == nil { await Task.yield() }
		cancelled.cancel()
		gate?.resume()
		await cancelled.value
		XCTAssertNil(presenter.picture(for: other))
		gate = nil
		let reload = Task { await presenter.load([other]) }
		while gate == nil { await Task.yield() }
		gate?.resume()
		await reload.value
		XCTAssertEqual(presenter.picture(for: other)?.pictureID, other.appPicId, "A cancelled load is asked for again")
		XCTAssertEqual(requests, 4)
	}

	func testARetryWaitingToRunNeverSupersedesNewerPeopleWithOlderOnes() async {
		var removed = Person.createPerson()
		removed.widgetPicId = nil
		let added = Person.createPerson()
		var fails = true
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, _ in
			if fails, picture.id == removed.appPicId { throw CoreError.missingValue }
			return Self.photo(.systemTeal)
		})
		await presenter.load([removed])
		fails = false
		let retry = Task { await presenter.retryFailedPictures() }
		await Task.yield()
		// The person leaves and another arrives while the retry waits for its turn.
		await presenter.load([added])
		await retry.value
		XCTAssertNil(presenter.picture(for: removed))
		XCTAssertEqual(presenter.picture(for: added)?.pictureID, added.appPicId)
	}

	func testARetryThatFailsAgainKeepsTheFallbackPhotoWithoutReadingItAgain() async {
		let person = Person.createPerson()
		var requests: [UUID?] = []
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, _ in
			requests.append(picture.id)
			guard picture.id == person.widgetPicId, requests.count == 2 else { throw CoreError.missingValue }
			return Self.photo(.systemTeal)
		})
		await presenter.load([person])
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, person.widgetPicId)
		await presenter.retryFailedPictures()
		XCTAssertEqual(requests, [person.appPicId, person.widgetPicId, person.appPicId])
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, person.widgetPicId, "The widget photo stays, not the monogram")
	}

	private static func photo(_ colour: UIColor) -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		return UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40), format: format).image { context in
			colour.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
		}
	}
}
