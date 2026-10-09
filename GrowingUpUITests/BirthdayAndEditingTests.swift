import XCTest

@MainActor
final class BirthdayAndEditingTests: XCTestCase {
	private var app: XCUIApplication!
	private var configuration: UITestConfiguration!
	private var overview: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.edit").firstMatch }
	private var confetti: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.confetti").firstMatch }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testLocalizedCountdownThresholdsAndIndicatorWindow() {
		for (clock, expected, name) in [
			("2027-01-02T08:00:00Z", "14 days", "days"),
			("2027-01-15T23:00:01Z", "60 minutes", "minutes"),
			("2027-01-15T00:00:01Z", "24 hours", "hours"),
			("2027-01-15T23:59:30Z", "30 seconds", "seconds")
		] {
			launch(clock: clock)
			app.buttons["person.birthday"].tap()
			let countdown = app.staticTexts["birthday.countdown"]
			XCTAssertTrue(countdown.waitForExistence(timeout: 5))
			XCTAssertEqual(countdown.label, expected)
			XCTAssertFalse(app.buttons["editor.save"].exists)
			checkpoint("birthday-countdown-\(name)-en")
			app.terminate()
		}
		launch(clock: "2027-01-02T08:00:00Z", locale: "ru")
		app.buttons["person.birthday"].tap()
		XCTAssertTrue(app.staticTexts["birthday.countdown"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["birthday.countdown"].label, "14 дней")
		XCTAssertTrue(app.staticTexts["До дня рождения"].exists)
		checkpoint("birthday-countdown-days-ru")
		app.terminate()
		launch(clock: "2027-01-01T08:00:00Z")
		XCTAssertFalse(app.buttons["person.birthday"].exists)
		checkpoint("birthday-outside-window")
	}

	func testLiveMidnightAndEveryBirthdayPageArrival() {
		launch(clock: "2027-01-15T23:59:40Z", runningClock: true)
		app.buttons["person.birthday"].tap()
		let countdown = app.staticTexts["birthday.countdown"]
		XCTAssertTrue(countdown.waitForExistence(timeout: 5))
		let initial = countdown.label
		XCTAssertTrue(initial.contains("seconds"))
		XCTAssertTrue(waitFor(countdown, predicate: NSPredicate(format: "label != %@", initial), timeout: 5))
		checkpoint("birthday-live-seconds")
		XCTAssertTrue(confetti.waitForExistence(timeout: 25))
		XCTAssertTrue(app.staticTexts["Happy birthday!"].exists)
		// Dismiss the popover without entering editing, then inspect the full-screen burst.
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.7)).tap()
		XCTAssertTrue(app.staticTexts["Happy birthday!"].waitForNonExistence(timeout: 5))
		checkpoint("birthday-midnight-confetti")
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
		app.swipeLeft()
		XCTAssertTrue(waitFor(app.staticTexts["person.name"], predicate: NSPredicate(format: "label == %@", "Boris"), timeout: 5))
		XCTAssertFalse(confetti.exists)
		app.swipeRight()
		// Capture the short-lived burst before name queries spend its animation window.
		XCTAssertTrue(confetti.waitForExistence(timeout: 5))
		XCTAssertEqual(confetti.value as? String, "2")
		checkpoint("birthday-return-confetti")
		XCTAssertTrue(waitFor(app.staticTexts["person.name"], predicate: NSPredicate(format: "label == %@", "Alice"), timeout: 5))
		XCTAssertFalse(app.buttons["editor.save"].exists)
	}

	func testExistingEditorDirtyStateCancelAndExplicitSave() {
		launch(clock: "2027-01-15T08:00:00Z")
		overview.tap()
		let save = app.buttons["editor.save"]
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		checkpoint("editor-save-disabled")
		let name = app.textFields["editor.name"]
		name.tap()
		name.typeText(" Draft")
		XCTAssertTrue(save.isEnabled)
		checkpoint("editor-save-enabled")
		name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
		XCTAssertFalse(save.isEnabled)
		dismissNameKeyboard()
		let pin = app.switches["editor.pin"]
		pin.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
		XCTAssertEqual(pin.value as? String, "0")
		XCTAssertTrue(save.isEnabled)
		pin.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
		XCTAssertEqual(pin.value as? String, "1")
		XCTAssertFalse(save.isEnabled)
		name.tap()
		name.typeText(" Unsaved")
		dismissNameKeyboard()
		pin.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
		XCTAssertEqual(pin.value as? String, "0")
		for slot in ["appPhoto", "widgetPhoto"] { choosePhoto(slot) }
		XCTAssertTrue(save.isEnabled)
		dismissEditor()
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Alice")
		overview.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		XCTAssertEqual(app.switches["editor.pin"].value as? String, "1")
		XCTAssertFalse(app.images["editor.appPhoto.loaded"].exists)
		XCTAssertFalse(app.images["editor.widgetPhoto.loaded"].exists)
		checkpoint("editor-cancel-restores-draft")
		name.tap()
		name.typeText(" Saved")
		save.tap()
		XCTAssertTrue(save.waitForNonExistence(timeout: 5))
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Alice Saved")
		checkpoint("editor-explicit-save-persisted")
	}

	func testBothPhotoChangesAndRemovalTrackDirtyState() {
		launch(clock: "2027-01-15T08:00:00Z")
		overview.tap()
		let save = app.buttons["editor.save"]
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		for slot in ["appPhoto", "widgetPhoto"] {
			XCTAssertFalse(save.isEnabled)
			choosePhoto(slot)
			XCTAssertTrue(save.isEnabled)
			app.buttons["editor.\(slot)"].tap()
			app.buttons["photo.source.remove"].tap()
			XCTAssertFalse(save.isEnabled)
		}
		choosePhoto("appPhoto")
		choosePhoto("widgetPhoto")
		save.tap()
		XCTAssertTrue(save.waitForNonExistence(timeout: 5))
		overview.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		app.buttons["editor.widgetPhoto"].tap()
		app.buttons["photo.source.remove"].tap()
		XCTAssertTrue(save.isEnabled)
		checkpoint("editor-photo-removal-dirty")
		dismissEditor()
		relaunch()
		overview.tap()
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
	}

	func testSavedBirthdayEditKeepsTheUpdatedCelebrationAfterTimerTicks() {
		launch(clock: "2027-01-15T08:00:00Z")
		overview.tap()
		app.buttons["editor.birthDate"].tap()
		let picker = app.datePickers["editor.birthDate.picker"]
		XCTAssertTrue(picker.waitForExistence(timeout: 5))
		picker.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "15")
		XCTAssertTrue(app.buttons["editor.save"].isEnabled)
		app.buttons["editor.save"].tap()
		XCTAssertTrue(confetti.waitForExistence(timeout: 5))
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
		app.buttons["person.birthday"].tap()
		XCTAssertTrue(app.staticTexts["Happy birthday!"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.staticTexts["birthday.countdown"].exists)
		checkpoint("birthday-edited-date-stays-current")
	}

	private func launch(clock: String, runningClock: Bool = false, locale: String = "en") {
		configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: .birthdays, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC",
			"GROWINGUP_BIRTHDAY_NOW": clock, "GROWINGUP_BIRTHDAY_CLOCK_RUNNING": runningClock ? "1" : "0"
		]
		app.launchArguments = ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ru" ? "ru_RU" : "en_US"]
		app.launch()
		XCTAssertTrue(overview.waitForExistence(timeout: 10))
	}

	private func relaunch() {
		app.terminate()
		configuration = configuration.forRelaunch()
		app.launchEnvironment[UITestConfiguration.environmentKey] = configuration.encoded
		app.launch()
		XCTAssertTrue(overview.waitForExistence(timeout: 10))
	}

	private func choosePhoto(_ slot: String) {
		app.buttons["editor.\(slot)"].tap()
		app.buttons["photo.source.photos"].tap()
		let thumbnail = app.buttons.matching(identifier: "photo.thumbnail").firstMatch
		XCTAssertTrue(thumbnail.waitForExistence(timeout: 5))
		thumbnail.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		app.buttons["crop.use"].tap()
		XCTAssertTrue(thumbnail.waitForNonExistence(timeout: 5))
	}

	private func dismissEditor() {
		let navigation = app.navigationBars.firstMatch
		let start = navigation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
		start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
	}

	private func dismissNameKeyboard() {
		// Expanding a birthday field clears the editor's name focus.
		let birthday = app.buttons["editor.birthDate"]
		birthday.tap()
		XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
		birthday.tap()
	}

	private func waitFor(_ element: XCUIElement, predicate: NSPredicate, timeout: TimeInterval) -> Bool {
		XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
