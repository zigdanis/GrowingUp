import XCTest

/// A hardware keyboard, as on an iPad with one attached, pages through people, adds a person and saves.
///
/// XCUITest delivers Return and Escape on their own only to text input, so the viewer's Return and Escape and edit
/// mode's Escape are left to a check with a real keyboard.
@MainActor
final class KeyboardShortcutTests: XCTestCase {
	private let app = XCUIApplication()
	private var personName: XCUIElement { app.buttons["person.name"] }
	private var save: XCUIElement { app.buttons["editor.save"] }

	func testTheArrowsPageAndCommandKeysAddAndSave() {
		continueAfterFailure = false
		launch()
		tile("Alice").tap()
		XCTAssertTrue(waitFor(personName, label: "Alice"))
		wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: personName)], timeout: 5)
		app.typeKey(.rightArrow, modifierFlags: [])
		XCTAssertTrue(waitFor(personName, label: "Boris"), "The right arrow pages to the next person")
		app.typeKey(.leftArrow, modifierFlags: [])
		XCTAssertTrue(waitFor(personName, label: "Alice"), "The left arrow pages back")
		closeViewer()
		app.typeKey("n", modifierFlags: .command)
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5), "Command-N adds a person")
		// Return puts the keyboard away, as the name field's Done does; then the edit mode's own keys answer again.
		name.typeText("Kim\n")
		XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
		XCTAssertTrue(save.isEnabled)
		// The edit mode takes the keyboard's keys back on the next turn of the run loop.
		Thread.sleep(forTimeInterval: 1)
		app.typeKey(.return, modifierFlags: .command)
		XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Command-Return saves")
		XCTAssertTrue(tile("Kim").waitForExistence(timeout: 5))
	}

	/// Drags the viewer down, which zooms it back into the shown person's tile.
	private func closeViewer() {
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).press(
			forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
		XCTAssertTrue(personName.waitForNonExistence(timeout: 5))
	}

	private func launch() {
		let configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: .sixPinned, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(tile("Alice").waitForExistence(timeout: 10))
	}

	private func tile(_ name: String) -> XCUIElement {
		app.buttons.matching(identifier: "people.tile").matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
	}

	private func waitFor(_ element: XCUIElement, label: String) -> Bool {
		let predicate = NSPredicate(format: "label == %@", label)
		return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed
	}
}
