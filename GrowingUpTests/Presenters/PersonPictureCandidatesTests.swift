import Core
import UIKit
import XCTest

@testable import GrowingUp

/// The mosaic tile and the viewer's page choose a person's picture by the same rule.
@MainActor
final class PersonPictureCandidatesTests: XCTestCase {
	func testTheAppPhotoComesFirstThenTheWidgetPhotoEachOnce() {
		var person = Person.createPerson()
		XCTAssertEqual(PersonPictureCandidates.ids(of: person), [person.appPicId, person.widgetPicId].compactMap { $0 })
		person.appPicId = nil
		XCTAssertEqual(PersonPictureCandidates.ids(of: person), [person.widgetPicId].compactMap { $0 })
		person.appPicId = person.widgetPicId
		XCTAssertEqual(PersonPictureCandidates.ids(of: person), [person.widgetPicId].compactMap { $0 }, "One shared picture loads once")
		person.appPicId = nil
		person.widgetPicId = nil
		XCTAssertEqual(PersonPictureCandidates.ids(of: person), [], "Nothing to load: the monogram")
	}

	func testTheViewerShowsAWidgetOnlyPhotoLikeTheTile() async {
		var person = Person.createPerson()
		person.appPicId = nil
		let widgetPhoto = Self.photo()
		let viewer = OverviewPresenter(loadImage: { picture in
			XCTAssertEqual(picture.id, person.widgetPicId)
			return widgetPhoto
		})
		await viewer.load(person: person)
		XCTAssertTrue(viewer.image === widgetPhoto)
		XCTAssertFalse(viewer.showsMonogram)
		let tile = MosaicPicturesPresenter(loadThumbnail: { _, _ in widgetPhoto })
		await tile.load([person])
		XCTAssertEqual(tile.picture(for: person)?.pictureID, person.widgetPicId, "Both show the widget photo")
	}

	func testTheViewerFallsBackPastAFailedPhotoToTheMonogram() async {
		let person = Person.createPerson()
		var requests: [UUID] = []
		let fallback = Self.photo()
		let viewer = OverviewPresenter(loadImage: { picture in
			requests.append(picture.id)
			guard picture.id == person.widgetPicId else { throw CoreError.missingValue }
			return fallback
		})
		await viewer.load(person: person)
		XCTAssertTrue(viewer.image === fallback, "A missing app photo gives way to the widget photo")
		XCTAssertEqual(requests, [person.appPicId, person.widgetPicId].compactMap { $0 })
		let broken = OverviewPresenter(loadImage: { _ in throw CoreError.missingValue })
		await broken.load(person: person)
		XCTAssertNil(broken.image)
		XCTAssertTrue(broken.showsMonogram, "With no photo loading, the page shows the monogram, as the tile does")
	}

	func testTheMonogramWaitsUntilNoPhotoLoads() async {
		let person = Person.createPerson()
		let started = AsyncStream.makeStream(of: Void.self)
		let gate = AsyncStream.makeStream(of: Void.self)
		let viewer = OverviewPresenter(loadImage: { _ in
			started.continuation.yield()
			for await _ in gate.stream { break }
			return Self.photo()
		})
		let loading = Task { await viewer.load(person: person) }
		for await _ in started.stream { break }
		XCTAssertFalse(viewer.showsMonogram, "A photo that is still loading never flashes the monogram")
		gate.continuation.yield()
		await loading.value
		XCTAssertNotNil(viewer.image)
	}

	private static func photo() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		return UIGraphicsImageRenderer(size: CGSize(width: 9, height: 16), format: format).image { context in
			UIColor.systemTeal.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 9, height: 16))
		}
	}
}
