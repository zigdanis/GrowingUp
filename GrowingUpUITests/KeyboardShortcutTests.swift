import XCTest

/// A hardware keyboard, as on an iPad with one attached, pages through people, edits, cancels, saves and closes.
@MainActor
final class KeyboardShortcutTests: XCTestCase {
	private let app = XCUIApplication()
	private var personName: XCUIElement { app.buttons["person.name"] }
	private var save: XCUIElement { app.buttons["editor.save"] }

	func testTheViewerAndEditModeAnswerTheKeyboard() {
		continueAfterFailure = false
		launch()
		tile("Alice").tap()
		XCTAssertTrue(waitFor(personName, label: "Alice"))
		wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: personName)], timeout: 5)
		app.typeKey(.rightArrow, modifierFlags: [])
		XCTAssertTrue(waitFor(personName, label: "Boris"), "The right arrow pages to the next person")
		app.typeKey(.leftArrow, modifierFlags: [])
		XCTAssertTrue(waitFor(personName, label: "Alice"), "The left arrow pages back")
		app.typeKey(.return, modifierFlags: [])
		XCTAssertTrue(save.waitForExistence(timeout: 5), "Return edits the shown person")
		app.typeKey(.escape, modifierFlags: [])
		XCTAssertTrue(save.waitForNonExistence(timeout: 5), "Escape cancels edit mode")
		XCTAssertTrue(waitFor(personName, label: "Alice"))
		app.typeKey(.escape, modifierFlags: [])
		XCTAssertTrue(personName.waitForNonExistence(timeout: 5), "Escape returns to the mosaic")
		app.typeKey("n", modifierFlags: .command)
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5), "Command-N adds a person")
		// Return puts the keyboard away, as the name field's Done does; then the edit mode's own keys answer again.
		name.typeText("Kim\n")
		app.typeKey(.return, modifierFlags: .command)
		XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Command-Return saves")
		XCTAssertTrue(tile("Kim").waitForExistence(timeout: 5))
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
