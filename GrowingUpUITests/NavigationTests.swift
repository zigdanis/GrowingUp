import XCTest

@MainActor
final class NavigationTests: XCTestCase {
	private var app: XCUIApplication!
	private var personName: XCUIElement { app.staticTexts["person.name"] }
	private var edit: XCUIElement { app.buttons["person.edit"] }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testNavigationAvatarsEditorAndWidgetLinks() {
		launch()
		XCTAssertEqual(personName.label, "Alice")
		XCTAssertTrue(app.buttons["people.avatar.0"].isSelected)
		XCTAssertEqual(app.buttons["people.avatar.1"].label, "Boris")
		XCTAssertEqual(app.buttons["people.avatar.add"].label, "Add person")
		app.buttons["people.avatar.1"].tap()
		XCTAssertTrue(waitFor(personName, label: "Boris"))
		XCTAssertTrue(app.buttons["people.avatar.1"].isSelected)
		checkpoint("navigation-avatar-selected")
		// Swiping still pages, and the strip follows the shown person.
		app.swipeLeft()
		XCTAssertTrue(waitFor(personName, label: "Clara"))
		XCTAssertTrue(app.buttons["people.avatar.2"].isSelected)
		app.buttons["people.avatar.add"].tap()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.buttons["people.avatar.add"].isSelected)
		checkpoint("navigation-add-page")
		app.buttons["people.avatar.0"].tap()
		XCTAssertTrue(waitFor(personName, label: "Alice"))
		app.buttons["people.avatar.1"].tap()
		XCTAssertTrue(waitFor(personName, label: "Boris"))
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 1.2)
		let save = app.buttons["editor.save"]
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertEqual(app.textFields["editor.name"].value as? String, "Boris")
		dismissEditor()
		XCTAssertEqual(personName.label, "Boris")
		edit.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		checkpoint("navigation-edit-button")
		dismissEditor()
		app.open(URL(string: "growingup-app://?personID=00000000-0000-0000-0000-000000000006")!)
		XCTAssertTrue(waitFor(personName, label: "Farah"))
		checkpoint("widget-sixth-link")
	}

	private func launch() {
		let configuration = UITestConfiguration(identifier: UUID(), resetStore: true, seed: .sixPinned, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", "Dark",
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(edit.waitForExistence(timeout: 10))
	}

	private func dismissEditor() {
		let navigation = app.navigationBars.firstMatch
		XCTAssertTrue(navigation.waitForExistence(timeout: 5))
		let start = navigation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
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
