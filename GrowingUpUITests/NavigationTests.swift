import XCTest

@MainActor
final class NavigationTests: XCTestCase {
	private var app: XCUIApplication!
	private var personName: XCUIElement { app.buttons["person.name"] }
	private var tiles: XCUIElementQuery { app.buttons.matching(identifier: "people.tile") }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testMosaicViewerEditorAndWidgetLinks() {
		launch(appearance: .dark)
		XCTAssertEqual(tiles.count, 6)
		XCTAssertTrue(tile("Alice").label.hasPrefix("Alice, 5 years"), tile("Alice").label)
		XCTAssertFalse(personName.exists, "Launch always shows the mosaic")
		XCTAssertTrue(app.buttons["person.add"].isHittable)
		checkpoint("mosaic-dark")
		tile("Boris").tap()
		XCTAssertTrue(waitFor(personName, label: "Boris"))
		checkpoint("viewer")
		// Swiping sideways pages through people in mosaic order.
		app.swipeLeft()
		XCTAssertTrue(waitFor(personName, label: "Clara"))
		closeViewer()
		XCTAssertTrue(tile("Clara").isHittable)
		tile("Boris").tap()
		XCTAssertTrue(waitFor(personName, label: "Boris"))
		// A tap anywhere on the person turns the viewer into its edit mode.
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
		let save = app.buttons["editor.save"]
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertEqual(app.textFields["editor.name"].value as? String, "Boris")
		XCTAssertFalse(save.isEnabled)
		checkpoint("viewer-tap-edit-mode")
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(save.waitForNonExistence(timeout: 5))
		XCTAssertTrue(waitFor(personName, label: "Boris"))
		closeViewer()
		app.open(URL(string: "growingup-app://?personID=00000000-0000-0000-0000-000000000006")!)
		XCTAssertTrue(waitFor(personName, label: "Farah"))
		checkpoint("widget-sixth-link")
		// The widget's person opens over the mosaic, so swiping down returns there.
		closeViewer()
		XCTAssertTrue(tile("Farah").exists)
	}

	func testMosaicFollowsTheLightTheme() {
		launch(appearance: .light)
		XCTAssertEqual(tiles.count, 6)
		checkpoint("mosaic-light")
	}

	func testLargestTextKeepsTheBirthdayLineWholeOnScreen() {
		launch(appearance: .dark, contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
		XCTAssertTrue(app.buttons["person.add"].isHittable)
		tile("Alice").tap()
		let countdown = app.staticTexts["birthday.countdown"]
		XCTAssertTrue(countdown.waitForExistence(timeout: 5))
		// The line wraps its countdown rather than truncating it and stays on screen.
		XCTAssertLessThanOrEqual(countdown.frame.maxY, app.frame.maxY)
		checkpoint("large-text-viewer")
	}

	private func launch(appearance: UITestAppearance, contentSize: String = "UICTContentSizeCategoryL") {
		let configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: .sixPinned, failNextSave: false, appearance: appearance)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", appearance.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", contentSize
		]
		app.launch()
		XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
	}

	private func tile(_ name: String) -> XCUIElement {
		tiles.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
	}

	/// Drags the viewer down, which zooms it back into the shown person's tile.
	private func closeViewer() {
		// A drag during the zoom-in, such as right after a widget link, is lost, so it waits for the viewer to settle.
		wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: personName)], timeout: 5)
		// A slow simulator can still drop the first drag after a widget link, so one more is allowed; a viewer that never
		// closes still fails.
		for _ in 0..<2 {
			app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).press(
				forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
			if personName.waitForNonExistence(timeout: 5) { return }
		}
		XCTFail("Swiping down did not close the viewer")
	}

	private func waitFor(_ element: XCUIElement, label: String) -> Bool {
		let predicate = NSPredicate(format: "label == %@", label)
		return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
