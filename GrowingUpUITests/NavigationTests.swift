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
		// A tap anywhere on the person opens the editor.
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
		let save = app.buttons["editor.save"]
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertEqual(app.textFields["editor.name"].value as? String, "Boris")
		XCTAssertFalse(save.isEnabled)
		checkpoint("viewer-tap-editor")
		dismissEditor()
		XCTAssertEqual(personName.label, "Boris")
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

	private func launch(appearance: UITestAppearance) {
		let configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: .sixPinned, failNextSave: false, appearance: appearance)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", appearance.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
	}

	private func tile(_ name: String) -> XCUIElement {
		tiles.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
	}

	/// Drags the viewer down, which zooms it back into the shown person's tile.
	private func closeViewer() {
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).press(
			forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
		XCTAssertTrue(personName.waitForNonExistence(timeout: 5))
	}

	private func dismissEditor() {
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		let navigation = app.navigationBars.firstMatch
		// iPhone Duo's outer display shows the sheet's bar vertically, so the drag starts at the top of the sheet there.
		let start =
			navigation.exists && navigation.frame.width > navigation.frame.height
			? navigation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
			: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
		start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
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
