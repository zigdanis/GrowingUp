import Core
import UIKit
import XCTest

@testable import GrowingUp

@MainActor
final class AvatarThumbnailsPresenterTests: XCTestCase {
	func testLoadsEachPictureOnceAsASmallThumbnailPreferringTheWidgetPhoto() async throws {
		var requests: [UUID?] = []
		let presenter = AvatarThumbnailsPresenter(loadImage: { picture in
			requests.append(picture.id)
			return Self.photo()
		})
		let person = Person.createPerson()
		await presenter.load([person])
		await presenter.load([person])
		XCTAssertEqual(requests, [person.widgetPicId])
		let thumbnail = try XCTUnwrap(presenter.thumbnail(for: person))
		XCTAssertLessThanOrEqual(min(thumbnail.size.width, thumbnail.size.height), 133)
	}

	func testFallsBackToTheAppPhotoThenThePlaceholderWithoutRetrying() async {
		var requests: [UUID?] = []
		var appOnly = Person.createPerson()
		var broken = Person.createPerson()
		var noPhotos = Person.createPerson()
		noPhotos.appPicId = nil
		noPhotos.widgetPicId = nil
		let loadable = appOnly.appPicId
		let presenter = AvatarThumbnailsPresenter(loadImage: { picture in
			requests.append(picture.id)
			guard picture.id == loadable else { throw CoreError.missingValue }
			return Self.photo()
		})
		await presenter.load([appOnly, broken, noPhotos])
		XCTAssertNotNil(presenter.thumbnail(for: appOnly))
		XCTAssertNil(presenter.thumbnail(for: broken))
		XCTAssertNil(presenter.thumbnail(for: noPhotos))
		XCTAssertEqual(requests, [appOnly.widgetPicId, appOnly.appPicId, broken.widgetPicId, broken.appPicId])
		await presenter.load([appOnly, broken, noPhotos])
		XCTAssertEqual(requests.count, 4, "Loaded and failed pictures are not requested again")
		appOnly.name = "Renamed"
		broken.name = "Renamed"
		await presenter.load([appOnly, broken])
		XCTAssertEqual(requests.count, 4)
	}

	func testChangedPhotoLoadsAgainAndRemovedPeopleAreDropped() async {
		var requests = 0
		let presenter = AvatarThumbnailsPresenter(loadImage: { _ in
			requests += 1
			return Self.photo()
		})
		var person = Person.createPerson()
		await presenter.load([person])
		person.widgetPicId = UUID()
		await presenter.load([person])
		XCTAssertEqual(requests, 2)
		XCTAssertEqual(presenter.thumbnails.count, 1)
		XCTAssertEqual(presenter.thumbnails.keys.first, person.widgetPicId)
		await presenter.load([])
		XCTAssertTrue(presenter.thumbnails.isEmpty)
	}

	private static func photo() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400), format: format).image { context in
			UIColor.systemTeal.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
		}
	}

	func testNewPreferredPhotoReplacesACachedFallback() async throws {
		let failing = UUID()
		var person = Person.createPerson()
		person.widgetPicId = failing
		let presenter = AvatarThumbnailsPresenter(loadImage: { picture in
			guard picture.id != failing else { throw CoreError.missingValue }
			return Self.photo()
		})
		await presenter.load([person])
		let appPicture = try XCTUnwrap(person.appPicId)
		XCTAssertNotNil(presenter.thumbnails[appPicture])
		XCTAssertNil(presenter.thumbnails[failing])
		let replacement = UUID()
		person.widgetPicId = replacement
		await presenter.load([person])
		XCTAssertNotNil(presenter.thumbnails[replacement], "The new widget photo loads although the app photo is cached")
	}
}
