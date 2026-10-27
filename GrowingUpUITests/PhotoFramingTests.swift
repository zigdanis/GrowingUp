import XCTest

/// A picked photo is kept whole as the original. Cropped tightly and saved, it reopens on that crop after a relaunch and
/// moves on past the crop's old edges; the circle framed on its own keeps its framing through both. Removing the photo
/// takes both pictures, and the photo menu follows.
///
/// Zooming out with two fingers is checked on a device: XCUITest starts an inward pinch with the fingers at the
/// element's corners, which for this full-screen photo lie on the top bar and the controls.
@MainActor
final class PhotoFramingTests: XCTestCase {
	private var app: XCUIApplication!
	private var configuration: UITestConfiguration!
	/// The shown person in the full-screen viewer; a tap on it turns the viewer into its edit mode.
	private var overview: XCUIElement { app.buttons["person.name"] }
	private var tiles: XCUIElementQuery { app.buttons.matching(identifier: "people.tile") }
	private var save: XCUIElement { app.buttons["editor.save"] }
	/// The photo the edit mode frames, which reports its zoom, such as "250%"; 100% shows as much as the screen holds.
	private var photo: XCUIElement { app.images["editor.appPhoto.loaded"] }
	private var reframe: XCUIElement { app.buttons["editor.widgetPhoto.reframe"] }
	/// The photo being cropped, which reports its zoom like `photo`.
	private var cropPhoto: XCUIElement { app.descendants(matching: .any)["crop.photo"] }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testEditPhotoReframeAndPersist() {
		launch()
		openEditor(of: "Alice")
		XCTAssertFalse(save.isEnabled)
		choosePhoto()
		checkpoint("photo-controls")
		let tight = cropTightly()
		XCTAssertEqual(photo.value as? String, tight, "The editor frames the whole photo where the crop left it")
		let circle = frameCircleOffCentre()
		saveAndRelaunch()
		checkpoint("saved-photo")
		openEditor(of: "Alice")
		XCTAssertTrue(photo.waitForExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		XCTAssertEqual(photo.value as? String, tight, "After a relaunch the editor opens on the saved crop")
		checkpoint("saved-photos-form")
		// The whole photo is there to frame again, so the tight crop moves on to what it left out; a picture cut to the
		// crop would have had no room to move.
		let centre = photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
		centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: 120, dy: -200)))
		XCTAssertTrue(save.isEnabled, "The photo moved past the crop's old edges, a new framing")
		checkpoint("editor-moved-past-crop")
		saveAndRelaunch()
		openEditor(of: "Alice")
		XCTAssertTrue(photo.waitForExistence(timeout: 5))
		XCTAssertEqual(photo.value as? String, tight, "The moved framing keeps its zoom")
		assertCircle(opensAt: circle, "The circle keeps its own framing")
		XCTAssertFalse(save.isEnabled)
		checkRemovalMenu()
	}
}

extension PhotoFramingTests {
	/// Picks the first photo and crops it tightly around its sun, in the top-right corner; returns the crop's zoom.
	private func cropTightly() -> String {
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		XCTAssertEqual(cropPhoto.value as? String, "100%")
		cropPhoto.pinch(withScale: 2.5, velocity: 2)
		// Down and to the left, as far as the photo's top edge allows, starting clear of the buttons.
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.2)).press(
			forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.98)))
		let tight = cropPhoto.value as? String ?? ""
		XCTAssertGreaterThan(Int(tight.dropLast()) ?? 0, 150, "A tight crop")
		checkpoint("main-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
		XCTAssertTrue(photo.waitForExistence(timeout: 5))
		return tight
	}

	/// Frames the widget picture's circle zoomed in and off-centre, and checks that it reopens there; returns its zoom.
	private func frameCircleOffCentre() -> String {
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertTrue(reframe.isEnabled)
		reframe.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		cropPhoto.pinch(withScale: 1.6, velocity: 2)
		let centre = cropPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
		centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: 60, dy: 90)))
		let circle = cropPhoto.value as? String ?? ""
		checkpoint("widget-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForNonExistence(timeout: 5))
		assertCircle(opensAt: circle, "The circle reopens on its framing", checkpoint: "widget-crop-reopened")
		return circle
	}

	/// Opens the circle's crop, checks the zoom it opens at, and cancels it.
	private func assertCircle(opensAt zoom: String, _ message: String, checkpoint name: String? = nil) {
		reframe.tap()
		XCTAssertTrue(app.buttons["crop.cancel"].waitForExistence(timeout: 5))
		XCTAssertEqual(cropPhoto.value as? String, zoom, message)
		if let name { checkpoint(name) }
		app.buttons["crop.cancel"].tap()
		XCTAssertTrue(app.buttons["crop.cancel"].waitForNonExistence(timeout: 5))
	}

	/// Removing the photo takes both pictures; the menu then offers no removal, and Cancel keeps them.
	private func checkRemovalMenu() {
		app.buttons["editor.appPhoto"].tap()
		let remove = app.buttons["photo.source.remove"]
		XCTAssertTrue(remove.waitForExistence(timeout: 5))
		checkpoint("image-menu-existing")
		remove.tap()
		XCTAssertTrue(photo.waitForNonExistence(timeout: 5))
		XCTAssertTrue(reframe.waitForNonExistence(timeout: 5), "No widget picture without a photo")
		XCTAssertTrue(save.isEnabled)
		app.buttons["editor.appPhoto"].tap()
		XCTAssertTrue(app.buttons["photo.source.photos"].waitForExistence(timeout: 5))
		XCTAssertFalse(remove.exists)
		checkpoint("image-menu-removed")
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
		dismissPhotos()
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(save.waitForNonExistence(timeout: 5))
		overview.tap()
		XCTAssertTrue(photo.waitForExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
	}

	private func launch() {
		configuration = UITestConfiguration(identifier: UUID(), resetStore: true, seed: .pinned, failNextSave: false, appearance: .light)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", configuration.appearance.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
	}

	private func relaunch() {
		app.terminate()
		configuration = configuration.forRelaunch()
		app.launchEnvironment[UITestConfiguration.environmentKey] = configuration.encoded
		app.launch()
		XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
	}

	private func saveAndRelaunch() {
		save.tap()
		XCTAssertTrue(save.waitForNonExistence(timeout: 5))
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		relaunch()
	}

	/// Opens `name` from the mosaic and taps the viewer once the zoom settles, which turns it into its edit mode.
	private func openEditor(of name: String) {
		let tile = tiles.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
		XCTAssertTrue(tile.waitForExistence(timeout: 5))
		// iPhone Duo can keep an empty window over the app that XCTest takes as covering the tile; a real touch at its
		// centre passes through to it.
		tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", name), object: overview)
		let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: overview)
		XCTAssertEqual(XCTWaiter.wait(for: [shown, settled], timeout: 5), .completed)
		overview.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
	}

	private func choosePhoto() {
		app.buttons["editor.appPhoto"].tap()
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
	}

	private func dismissPhotos() {
		let grabber = app.buttons["Sheet Grabber"].firstMatch
		XCTAssertTrue(grabber.waitForExistence(timeout: 5))
		grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
			forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
