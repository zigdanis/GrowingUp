import Core
import UIKit
import XCTest

@testable import GrowingUp

@MainActor
final class MosaicPicturesPresenterTests: XCTestCase {
	func testLoadsEachPictureOnceAsAThumbnailPreferringTheAppPhotoWithItsAverageColour() async throws {
		var requests: [UUID?] = []
		var sizes: Set<Int> = []
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, maxPixelSize in
			requests.append(picture.id)
			sizes.insert(maxPixelSize)
			return Self.photo(.systemTeal)
		})
		let person = Person.createPerson()
		await presenter.load([person])
		await presenter.load([person])
		XCTAssertEqual(requests, [person.appPicId])
		XCTAssertEqual(sizes, [960], "Tiles ask for a thumbnail, not the full-size photo")
		let picture = try XCTUnwrap(presenter.picture(for: person))
		XCTAssertEqual(picture.pictureID, person.appPicId)
		let average = try XCTUnwrap(picture.averageColor)
		XCTAssertTrue(Self.isClose(average, to: .systemTeal), "\(average)")
	}

	func testFallsBackToTheWidgetPhotoThenTheMonogramWithoutRetrying() async throws {
		var requests: [UUID?] = []
		var widgetOnly = Person.createPerson()
		var broken = Person.createPerson()
		var noPhotos = Person.createPerson()
		noPhotos.appPicId = nil
		noPhotos.widgetPicId = nil
		let loadable = widgetOnly.widgetPicId
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, _ in
			requests.append(picture.id)
			guard picture.id == loadable else { throw CoreError.missingValue }
			return Self.photo(.systemTeal)
		})
		await presenter.load([widgetOnly, broken, noPhotos])
		XCTAssertEqual(presenter.picture(for: widgetOnly)?.pictureID, loadable)
		XCTAssertNil(presenter.picture(for: broken)?.pictureID)
		XCTAssertNotNil(presenter.picture(for: broken)?.averageColor, "A monogram tints the background too")
		XCTAssertNil(presenter.picture(for: noPhotos)?.pictureID)
		XCTAssertEqual(requests, [widgetOnly.appPicId, widgetOnly.widgetPicId, broken.appPicId, broken.widgetPicId])
		await presenter.load([widgetOnly, broken, noPhotos])
		XCTAssertEqual(requests.count, 4, "Loaded and failed pictures are not requested again")
		let monogram = try XCTUnwrap(presenter.picture(for: broken)?.image)
		widgetOnly.name = "Renamed"
		broken.name = "Renamed"
		await presenter.load([widgetOnly, broken])
		XCTAssertEqual(requests.count, 4)
		XCTAssertFalse(presenter.picture(for: broken)?.image === monogram, "A renamed person gets a new initial")
		XCTAssertEqual(presenter.picture(for: broken)?.name, "Renamed")
	}

	func testChangedPhotoLoadsAgainAndRemovedPeopleAreDropped() async {
		var requests = 0
		let presenter = MosaicPicturesPresenter(loadThumbnail: { _, _ in
			requests += 1
			return Self.photo(.systemTeal)
		})
		var person = Person.createPerson()
		await presenter.load([person])
		person.appPicId = UUID()
		await presenter.load([person])
		XCTAssertEqual(requests, 2)
		XCTAssertEqual(presenter.pictures.count, 1)
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, person.appPicId)
		await presenter.load([])
		XCTAssertTrue(presenter.pictures.isEmpty)
	}

	func testNewPreferredPhotoReplacesACachedFallback() async throws {
		let failing = UUID()
		var person = Person.createPerson()
		person.appPicId = failing
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, _ in
			guard picture.id != failing else { throw CoreError.missingValue }
			return Self.photo(.systemTeal)
		})
		await presenter.load([person])
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, person.widgetPicId)
		let replacement = UUID()
		person.appPicId = replacement
		await presenter.load([person])
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, replacement, "The new app photo loads although the widget photo is cached")
	}

	func testAmbientSeedsAreTheFirstFourLoadedColoursInMosaicOrder() async {
		let colours: [UIColor] = [.red, .green, .blue, .yellow, .purple]
		let people = colours.map { _ in Person.createPerson() }
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, _ in
			let index = people.firstIndex { $0.appPicId == picture.id } ?? 0
			return Self.photo(colours[index])
		})
		XCTAssertTrue(presenter.ambientSeeds(for: people).isEmpty)
		await presenter.load(people)
		let seeds = presenter.ambientSeeds(for: people)
		XCTAssertEqual(seeds.count, 4)
		for (seed, colour) in zip(seeds, colours) {
			XCTAssertTrue(Self.isClose(seed, to: colour), "\(seed) vs \(colour)")
		}
	}

	func testASupersededLoadPublishesNothingOverTheNewerPictures() async {
		var person = Person.createPerson()
		var renamed = Person.createPerson()
		renamed.appPicId = nil
		renamed.widgetPicId = nil
		let outdated = person.appPicId
		var gate: CheckedContinuation<Void, Never>?
		let presenter = MosaicPicturesPresenter(loadThumbnail: { picture, _ in
			if picture.id == outdated { await withCheckedContinuation { gate = $0 } }
			return Self.photo(.systemTeal)
		})
		let stale = Task { await presenter.load([person, renamed]) }
		while gate == nil { await Task.yield() }
		person.appPicId = UUID()
		renamed.name = "Renamed"
		await presenter.load([person, renamed])
		gate?.resume()
		await stale.value
		XCTAssertEqual(presenter.picture(for: person)?.pictureID, person.appPicId, "The replacement photo stays")
		XCTAssertEqual(presenter.picture(for: renamed)?.name, "Renamed", "The new monogram stays")
	}

	func testASupersededLoadDoesNotBringBackARemovedPerson() async {
		let person = Person.createPerson()
		var gate: CheckedContinuation<Void, Never>?
		let presenter = MosaicPicturesPresenter(loadThumbnail: { _, _ in
			await withCheckedContinuation { gate = $0 }
			return Self.photo(.systemTeal)
		})
		let stale = Task { await presenter.load([person]) }
		while gate == nil { await Task.yield() }
		await presenter.load([])
		gate?.resume()
		await stale.value
		XCTAssertTrue(presenter.pictures.isEmpty)
	}

	func testACancelledLoadPublishesNothing() async {
		let person = Person.createPerson()
		var gate: CheckedContinuation<Void, Never>?
		let presenter = MosaicPicturesPresenter(loadThumbnail: { _, _ in
			// Like a loader that ignores cancellation, it still returns its picture.
			await withCheckedContinuation { gate = $0 }
			return Self.photo(.systemTeal)
		})
		let stale = Task { await presenter.load([person]) }
		while gate == nil { await Task.yield() }
		stale.cancel()
		gate?.resume()
		await stale.value
		XCTAssertNil(presenter.picture(for: person))
	}

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

	private static func photo(_ colour: UIColor, size: CGSize = CGSize(width: 600, height: 400)) -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.preferredRange = .standard
		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			colour.setFill()
			context.fill(CGRect(origin: .zero, size: size))
		}
	}

	private static func isClose(_ colour: UIColor, to expected: UIColor) -> Bool {
		let resolved = expected.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
		return zip(rgb(of: colour), rgb(of: resolved)).allSatisfy { abs($0 - $1) < 0.03 }
	}

	private static func rgb(of colour: UIColor) -> [CGFloat] {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		colour.getRed(&red, green: &green, blue: &blue, alpha: nil)
		return [red, green, blue]
	}
}
