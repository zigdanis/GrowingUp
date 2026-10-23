import XCTest

@MainActor
final class BirthdayAndEditingTests: XCTestCase {
	private var app: XCUIApplication!
	private var configuration: UITestConfiguration!
	/// The shown person in the full-screen viewer; a tap on it opens the editor.
	private var overview: XCUIElement { app.buttons["person.name"] }
	private var confetti: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.confetti").firstMatch }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testBirthdayEditAndCelebrationChoice() {
		launch(clock: "2027-01-15T08:00:00Z")
		overview.tap()
		app.buttons["editor.birthDate"].tap()
		let picker = app.datePickers["editor.birthDate.picker"]
		XCTAssertTrue(picker.waitForExistence(timeout: 5))
		picker.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "15")
		app.buttons["editor.birthDate"].tap()
		// The chips move up while the wheel collapses; a tap during that animation can miss them.
		XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
		let celebrate = app.descendants(matching: .any).matching(identifier: "editor.celebrate").firstMatch
		XCTAssertEqual(celebrate.value as? String, "1")
		celebrate.tap()
		XCTAssertEqual(celebrate.value as? String, "0")
		celebrate.tap()
		XCTAssertEqual(celebrate.value as? String, "1")
		XCTAssertTrue(app.buttons["editor.save"].isEnabled)
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["birthday.countdown"].label, "Birthday today 🎂")
		checkpoint("birthday-edited-date-stays-current")
	}

}

extension BirthdayAndEditingTests {
	private func launch(clock: String) {
		configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: .birthdays, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC", "GROWINGUP_BIRTHDAY_NOW": clock]
		app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
		app.launch()
		let first = app.buttons.matching(identifier: "people.tile").firstMatch
		XCTAssertTrue(first.waitForExistence(timeout: 10))
		first.tap()
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
