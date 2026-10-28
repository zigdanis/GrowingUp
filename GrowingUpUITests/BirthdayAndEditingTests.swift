import XCTest

@MainActor
final class BirthdayAndEditingTests: XCTestCase {
	private var app: XCUIApplication!
	private var configuration: UITestConfiguration!
	/// The shown person in the full-screen viewer; a tap on it turns the viewer into its edit mode.
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
		let day = picker.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "January 15")).firstMatch
		XCTAssertTrue(day.waitForExistence(timeout: 5), picker.debugDescription)
		day.tap()
		// A tap on the dim layer below the centred calendar closes it.
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
		XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
		XCTAssertEqual(app.buttons["editor.birthDate"].value as? String, "Jan 15, 2020")
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

	func testBirthdayCountdownFollowsSavedCelebrationChoice() {
		launch(clock: "2027-01-15T08:00:00Z")
		let countdown = app.staticTexts["birthday.countdown"]
		XCTAssertTrue(countdown.waitForExistence(timeout: 5))
		let originalCountdown = countdown.label
		overview.tap()
		let celebrate = app.descendants(matching: .any).matching(identifier: "editor.celebrate").firstMatch
		XCTAssertEqual(celebrate.value as? String, "1")
		celebrate.tap()
		XCTAssertEqual(celebrate.value as? String, "0")
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		XCTAssertTrue(countdown.waitForNonExistence(timeout: 5))
		checkpoint("birthday-countdown-disabled")
		overview.tap()
		XCTAssertEqual(celebrate.value as? String, "0", "The saved birthday choice must remain off when editing again")
		celebrate.tap()
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
		XCTAssertTrue(countdown.waitForExistence(timeout: 5))
		XCTAssertEqual(countdown.label, originalCountdown)
		checkpoint("birthday-countdown-enabled")
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
