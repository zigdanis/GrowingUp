import XCTest

/// The viewer's in-place edit mode for an existing person, which only Cancel and Done leave.
@MainActor
final class EditInPlaceTests: XCTestCase {
	private var app: XCUIApplication!
	private var configuration: UITestConfiguration!
	/// The shown person in the full-screen viewer; edit mode hides it until Cancel or Done.
	private var overview: XCUIElement { app.buttons["person.name"] }
	private var tiles: XCUIElementQuery { app.buttons.matching(identifier: "people.tile") }
	private var nameField: XCUIElement { app.textFields["editor.name"] }
	private var done: XCUIElement { app.buttons["editor.save"] }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testDoneSavesTheNameAndDateForTheNextLaunch() {
		launch()
		openPerson("Alice")
		enterEditMode()
		XCTAssertTrue(done.waitForExistence(timeout: 5))
		XCTAssertFalse(done.isEnabled, "Nothing changed yet")
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 5))
		checkpoint("edit-mode")
		rename(to: "Alicia")
		XCTAssertTrue(done.isEnabled)
		app.buttons["editor.birthDate"].tap()
		let calendar = app.datePickers["editor.birthDate.picker"]
		XCTAssertTrue(calendar.waitForExistence(timeout: 5))
		checkpoint("edit-calendar")
		// The seed makes Alice 5 years, 3 months and 12 days old on the fixed clock, born October 3, 2021.
		selectDay("October 15", in: calendar)
		closeCard()
		XCTAssertTrue(calendar.waitForNonExistence(timeout: 5))
		XCTAssertEqual(app.buttons["editor.birthDate"].value as? String, "Oct 15, 2021")
		app.buttons["editor.birthTime"].tap()
		XCTAssertTrue(app.datePickers["editor.birthTime.picker"].waitForExistence(timeout: 5))
		checkpoint("edit-time")
		closeCard()
		done.tap()
		XCTAssertTrue(done.waitForNonExistence(timeout: 5))
		XCTAssertTrue(waitForName("Alicia"), "Done returns to the viewer, showing the saved person")
		relaunch()
		openPerson("Alicia")
		enterEditMode()
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		XCTAssertEqual(nameField.value as? String, "Alicia")
		XCTAssertEqual(app.buttons["editor.birthDate"].value as? String, "Oct 15, 2021")
		XCTAssertFalse(done.isEnabled)
	}

	func testCancelDropsTheChangesWithoutAQuestion() {
		launch()
		openPerson("Boris")
		enterEditMode()
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		rename(to: "Unsaved")
		let celebrate = control("editor.celebrate")
		XCTAssertEqual(celebrate.value as? String, "1")
		celebrate.tap()
		XCTAssertEqual(celebrate.value as? String, "0")
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(done.waitForNonExistence(timeout: 5))
		XCTAssertFalse(app.alerts.firstMatch.exists)
		XCTAssertFalse(app.sheets.firstMatch.exists)
		XCTAssertTrue(waitForName("Boris"), "Cancel returns to the unchanged viewer")
		enterEditMode()
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		XCTAssertEqual(nameField.value as? String, "Boris")
		XCTAssertEqual(control("editor.celebrate").value as? String, "1")
		app.buttons["editor.cancel"].tap()
		relaunch()
		XCTAssertTrue(tile("Boris").waitForExistence(timeout: 5))
		XCTAssertFalse(tile("Unsaved").exists)
	}

	func testEditModeLocksTheViewersSwipes() {
		launch()
		openPerson("Boris")
		enterEditMode()
		XCTAssertTrue(done.waitForExistence(timeout: 5))
		// Swiping down or sideways moves the photo now; the viewer neither closes nor pages.
		dragDown()
		app.swipeLeft()
		XCTAssertTrue(done.exists)
		XCTAssertEqual(nameField.value as? String, "Boris")
		checkpoint("edit-mode-after-swipes")
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(waitForName("Boris"))
		// Back in the viewer, the swipes work again.
		app.swipeLeft()
		XCTAssertTrue(waitForName("Clara"))
		waitForSettledViewer()
		dragDown()
		XCTAssertTrue(overview.waitForNonExistence(timeout: 5))
		XCTAssertTrue(tile("Clara").waitForExistence(timeout: 5))
	}
}

extension EditInPlaceTests {
	private func launch() {
		configuration = UITestConfiguration(identifier: UUID(), resetStore: true, seed: .sixPinned, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", "Dark",
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

	private func tile(_ name: String) -> XCUIElement {
		tiles.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
	}

	/// Opens `name` from the mosaic once the zoom has settled, so a tap or drag right after is not lost.
	private func openPerson(_ name: String) {
		XCTAssertTrue(tile(name).waitForExistence(timeout: 5))
		// Once edit mode has closed, iPhone Duo keeps an empty window over the app that XCTest takes as covering the tile, so
		// a plain tap lands on its rounded corner; a real touch at its centre passes through to it.
		tile(name).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		XCTAssertTrue(waitForName(name))
		waitForSettledViewer()
	}

	/// Waits until the viewer's page has settled after a zoom or a page change; a touch while it moves can be lost.
	private func waitForSettledViewer() {
		let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: overview)
		XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
	}

	/// Taps the settled viewer, which turns it into its edit mode. Like the tiles, it is tapped at its centre, which iPhone
	/// Duo's leftover empty window cannot intercept.
	private func enterEditMode() {
		waitForSettledViewer()
		overview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		XCTAssertTrue(done.waitForExistence(timeout: 5))
	}

	/// Replaces the name; Return only hides the keyboard.
	private func rename(to newName: String) {
		let current = nameField.value as? String ?? ""
		// A tap past the end of the name puts the cursor after it.
		nameField.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
		nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + newName + "\n")
		XCTAssertEqual(nameField.value as? String, newName)
		XCTAssertTrue(done.exists, "Return keeps edit mode open")
	}

	/// Picks the day whose accessibility label ends with `day`, such as "September 15", in the calendar card.
	private func selectDay(_ day: String, in calendar: XCUIElement) {
		let button = calendar.buttons.matching(NSPredicate(format: "label ENDSWITH %@", day)).firstMatch
		XCTAssertTrue(button.waitForExistence(timeout: 5), calendar.debugDescription)
		button.tap()
	}

	/// Taps the dim layer below the centred card, which closes it.
	private func closeCard() {
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
		XCTAssertTrue(app.descendants(matching: .any)["editor.popover"].waitForNonExistence(timeout: 5))
	}

	/// Drags from the middle of the photo to the bottom, the gesture that closes the viewer outside edit mode.
	private func dragDown() {
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(
			forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
	}

	/// Edit-mode switches are buttons that report their state as a "1"/"0" value.
	private func control(_ identifier: String) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	private func waitForName(_ name: String) -> Bool {
		let predicate = NSPredicate(format: "label == %@", name)
		return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: overview)], timeout: 5) == .completed
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
