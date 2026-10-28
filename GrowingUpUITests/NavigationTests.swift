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

	/// Captures the icon as SpringBoard renders it, which no screenshot of the app itself shows.
	func testHomeScreenShowsTheAppIcon() {
		launch(appearance: .light)
		XCUIDevice.shared.press(.home)
		defer { app.activate() }
		let springBoard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
		// On Duo, the first Home press can leave the app switcher open instead of showing the icon grid.
		let switcher = springBoard.otherElements["AppSwitcherContentView"]
		if switcher.waitForExistence(timeout: 2) {
			XCUIDevice.shared.press(.home)
			XCTAssertTrue(switcher.waitForNonExistence(timeout: 5))
		}
		let icon = springBoard.icons["GrowingUp"].firstMatch
		XCTAssertTrue(icon.waitForExistence(timeout: 10))
		wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: icon)], timeout: 10)
		let attachment = XCTAttachment(screenshot: icon.screenshot())
		attachment.name = "app-icon-soft-lift"
		attachment.lifetime = .keepAlways
		add(attachment)
	}

	func testLargestTextKeepsTheBirthdayLineWholeOnScreen() {
		launch(appearance: .dark, contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
		XCTAssertTrue(app.buttons["person.add"].isHittable)
		XCTAssertEqual(tile("Alice").label, "Alice, 5 years, 3 months", "VoiceOver reads a tile as its name and age, once")
		checkpoint("large-text-mosaic")
		tile("Alice").tap()
		let countdown = app.staticTexts["birthday.countdown"]
		XCTAssertTrue(countdown.waitForExistence(timeout: 5))
		// The line wraps its countdown rather than truncating it and stays on screen.
		XCTAssertLessThanOrEqual(countdown.frame.maxY, app.frame.maxY)
		checkpoint("large-text-viewer")
	}

	func testLargestTextKeepsEveryEditModeControlOnScreen() {
		launch(appearance: .dark, contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
		tile("Alice").tap()
		XCTAssertTrue(waitFor(personName, label: "Alice"))
		wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: personName)], timeout: 5)
		personName.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		// Alice has a photo, so all five round controls show.
		assertOnScreen(editModeControls + ["editor.widgetPhoto.reframe", "editor.remove"])
		checkpoint("large-text-edit-mode")
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
		closeViewer()
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5))
		// Return hides the keyboard, which covers the round controls while the name is typed.
		name.typeText("\n")
		XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
		assertOnScreen(editModeControls)
		checkpoint("large-text-new-person")
	}

	func testLargestTextKeepsTheInvitationWholeAboveTheAddButton() {
		launch(appearance: .dark, contentSize: "UICTContentSizeCategoryAccessibilityXXXL", seed: .empty)
		let add = app.buttons["person.add"]
		XCTAssertTrue(add.waitForExistence(timeout: 10))
		let window = app.windows.firstMatch.frame
		XCTAssertTrue(add.isHittable)
		XCTAssertTrue(window.contains(add.frame), "Add at \(add.frame) leaves \(window)")
		// The button stays a one-line capsule rather than a block of wrapped text.
		XCTAssertGreaterThan(add.frame.width, add.frame.height * 2, "Add at \(add.frame)")
		checkpoint("large-text-invitation")
		let title = app.staticTexts["people.invitation.title"]
		let message = app.staticTexts["people.invitation.message"]
		XCTAssertTrue(title.waitForExistence(timeout: 5))
		assertAboveAdd(title, add: add, window: window)
		// Where the invitation does not fit above the button, it scrolls rather than truncating.
		if message.frame.maxY > add.frame.minY { title.swipeUp() }
		assertAboveAdd(message, add: add, window: window)
	}

	/// The edit mode's fields, its Cancel and Done, and the round controls every person has.
	private var editModeControls: [String] {
		[
			"editor.name", "editor.birthDate", "editor.birthTime", "editor.cancel", "editor.save", "editor.appPhoto", "editor.pin",
			"editor.celebrate"
		]
	}

	/// Each control exists, takes a tap and lies whole inside the window.
	private func assertOnScreen(_ identifiers: [String], file: StaticString = #filePath, line: UInt = #line) {
		let window = app.windows.firstMatch.frame
		for identifier in identifiers {
			let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
			XCTAssertTrue(element.waitForExistence(timeout: 5), identifier, file: file, line: line)
			XCTAssertTrue(element.isHittable, identifier, file: file, line: line)
			XCTAssertTrue(window.contains(element.frame), "\(identifier) at \(element.frame) leaves \(window)", file: file, line: line)
		}
	}

	private func launch(appearance: UITestAppearance, contentSize: String = "UICTContentSizeCategoryL", seed: UITestSeed = .sixPinned) {
		let configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: seed, failNextSave: false, appearance: appearance)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", appearance.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", contentSize
		]
		app.launch()
		guard seed != .empty else { return }
		XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
	}

	private func assertAboveAdd(_ element: XCUIElement, add: XCUIElement, window: CGRect) {
		XCTAssertTrue(window.contains(element.frame), "\(element.identifier) at \(element.frame) leaves \(window)")
		XCTAssertLessThanOrEqual(
			element.frame.maxY, add.frame.minY, "\(element.identifier) at \(element.frame) runs under the Add button at \(add.frame)")
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
