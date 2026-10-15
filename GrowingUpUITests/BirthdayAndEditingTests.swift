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
		checkpoint("birthday-midnight-confetti-poppers")
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
		app.swipeLeft()
		XCTAssertTrue(waitFor(app.staticTexts["person.name"], predicate: NSPredicate(format: "label == %@", "Boris"), timeout: 5))
		XCTAssertFalse(confetti.exists)
		app.swipeRight()
		// Capture the short-lived burst before name queries spend its animation window.
		XCTAssertTrue(confetti.waitForExistence(timeout: 5))
		XCTAssertEqual(confetti.value as? String, "2")
		// Let the falling confetti reach the middle of the screen before capturing it.
		Thread.sleep(forTimeInterval: 1.2)
		checkpoint("birthday-return-confetti-rain")
		XCTAssertTrue(waitFor(app.staticTexts["person.name"], predicate: NSPredicate(format: "label == %@", "Alice"), timeout: 5))
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
		// Each later arrival continues the rotation of celebration styles.
		app.swipeLeft()
		XCTAssertTrue(waitFor(app.staticTexts["person.name"], predicate: NSPredicate(format: "label == %@", "Boris"), timeout: 5))
		app.swipeRight()
		XCTAssertTrue(confetti.waitForExistence(timeout: 5))
		XCTAssertEqual(confetti.value as? String, "3")
		Thread.sleep(forTimeInterval: 1.2)
		checkpoint("birthday-return-confetti-fireworks")
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
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
		// Return dismisses the keyboard so it cannot cover the chips.
		name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "\n")
		XCTAssertFalse(save.isEnabled)
		let pin = chip("editor.pin")
		pin.tap()
		XCTAssertEqual(pin.value as? String, "0")
		XCTAssertTrue(save.isEnabled)
		pin.tap()
		XCTAssertEqual(pin.value as? String, "1")
		XCTAssertFalse(save.isEnabled)
		name.tap()
		name.typeText(" Unsaved\n")
		pin.tap()
		XCTAssertEqual(pin.value as? String, "0")
		choosePhoto()
		reframeWidgetPhoto()
		XCTAssertTrue(save.isEnabled)
		cancelEditor(discarding: true)
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Alice")
		overview.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		XCTAssertEqual(chip("editor.pin").value as? String, "1")
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

	func testPhotoChangeReframeAndRemovalTrackDirtyState() {
		launch(clock: "2027-01-15T08:00:00Z")
		overview.tap()
		let save = app.buttons["editor.save"]
		let widgetPhoto = app.images["editor.widgetPhoto.loaded"]
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		XCTAssertFalse(app.buttons["editor.widgetPhoto.reframe"].isEnabled)
		choosePhoto()
		XCTAssertTrue(save.isEnabled)
		XCTAssertTrue(widgetPhoto.waitForExistence(timeout: 5))
		removePhoto()
		XCTAssertFalse(save.isEnabled)
		XCTAssertTrue(widgetPhoto.waitForNonExistence(timeout: 5))
		choosePhoto()
		save.tap()
		XCTAssertTrue(save.waitForNonExistence(timeout: 5))
		overview.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertFalse(save.isEnabled)
		reframeWidgetPhoto()
		XCTAssertTrue(save.isEnabled)
		checkpoint("editor-reframe-dirty")
		cancelEditor(discarding: true)
		overview.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		removePhoto()
		XCTAssertTrue(save.isEnabled)
		XCTAssertTrue(widgetPhoto.waitForNonExistence(timeout: 5))
		checkpoint("editor-photo-removal-dirty")
		cancelEditor(discarding: true)
		relaunch()
		overview.tap()
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertTrue(widgetPhoto.waitForExistence(timeout: 5))
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

	func testCelebrateChipControlsConfetti() {
		launch(clock: "2027-01-15T08:00:00Z")
		overview.tap()
		let born = app.buttons["editor.birthDate"]
		XCTAssertTrue(born.waitForExistence(timeout: 5))
		born.tap()
		let picker = app.datePickers["editor.birthDate.picker"]
		XCTAssertTrue(picker.waitForExistence(timeout: 5))
		picker.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "15")
		born.tap()
		let celebrate = chip("editor.celebrate")
		XCTAssertEqual(celebrate.value as? String, "1")
		celebrate.tap()
		XCTAssertEqual(celebrate.value as? String, "0")
		checkpoint("editor-celebrate-off")
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 20))
		// The birthday is today, so the indicator stays while the opted-out confetti never starts.
		XCTAssertTrue(app.buttons["person.birthday"].waitForExistence(timeout: 5))
		// Every arrival on a birthday page starts a celebration, so an opted-out person must stay quiet on return.
		leaveAndReturn()
		// Boris celebrates on the fixed clock too, so confetti only counts once Alice is the selected page.
		XCTAssertTrue(waitFor(app.staticTexts["person.name"], predicate: NSPredicate(format: "label == %@", "Alice"), timeout: 5))
		XCTAssertFalse(confetti.waitForExistence(timeout: 3))
		overview.tap()
		XCTAssertTrue(celebrate.waitForExistence(timeout: 5))
		XCTAssertEqual(celebrate.value as? String, "0")
		celebrate.tap()
		XCTAssertEqual(celebrate.value as? String, "1")
		app.buttons["editor.save"].tap()
		// Saving can keep the editor busy for seconds, so return to the page after it closes instead of racing the burst.
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 20))
		leaveAndReturn()
		XCTAssertTrue(confetti.waitForExistence(timeout: 8))
		XCTAssertEqual(app.staticTexts["person.name"].label, "Alice")
	}
}

extension BirthdayAndEditingTests {
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

	/// Editor chips are buttons that report their state as a "1"/"0" value.
	private func chip(_ identifier: String) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	private func choosePhoto() {
		app.buttons["editor.appPhoto"].tap()
		app.buttons["photo.source.photos"].tap()
		let thumbnail = app.buttons.matching(identifier: "photo.thumbnail").firstMatch
		XCTAssertTrue(thumbnail.waitForExistence(timeout: 5))
		thumbnail.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		app.buttons["crop.use"].tap()
		XCTAssertTrue(thumbnail.waitForNonExistence(timeout: 5))
	}

	private func reframeWidgetPhoto() {
		let reframe = app.buttons["editor.widgetPhoto.reframe"]
		XCTAssertTrue(reframe.waitForExistence(timeout: 5))
		reframe.tap()
		let use = app.buttons["crop.use"]
		XCTAssertTrue(use.waitForExistence(timeout: 5))
		use.tap()
		XCTAssertTrue(use.waitForNonExistence(timeout: 5))
	}

	private func removePhoto() {
		app.buttons["editor.appPhoto"].tap()
		let remove = app.buttons["photo.source.remove"]
		XCTAssertTrue(remove.waitForExistence(timeout: 5))
		remove.tap()
	}

	/// Cancels the editor, confirming the discard dialog that unsaved changes raise.
	private func cancelEditor(discarding: Bool) {
		app.buttons["editor.cancel"].tap()
		if discarding {
			let discard = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "editor.discard", "Discard")).firstMatch
			XCTAssertTrue(discard.waitForExistence(timeout: 5))
			discard.tap()
		}
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
	}

	/// Swipes to the next person and back, which is how a birthday page is arrived on again.
	private func leaveAndReturn() {
		app.swipeLeft()
		XCTAssertTrue(waitFor(app.staticTexts["person.name"], predicate: NSPredicate(format: "label == %@", "Boris"), timeout: 5))
		app.swipeRight()
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
