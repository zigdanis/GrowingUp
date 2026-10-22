import XCTest

@MainActor
final class JourneyTests: XCTestCase {
	private var app: XCUIApplication!
	private var identifier = UUID().uuidString
	private var configuration: UITestConfiguration!

	private var overview: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.edit").firstMatch }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
		identifier = UUID().uuidString
	}

	func testAddAndRelaunch() {
		launch()
		checkpoint("empty")
		addPerson(birthPeriod: "PM", capturePickers: true)
		checkpoint("overview")
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
		overview.tap()
		let born = app.buttons["editor.birthDate"]
		XCTAssertTrue(born.waitForExistence(timeout: 5))
		XCTAssertTrue(born.label.contains("January 10, 2027"), born.label)
		XCTAssertTrue(born.label.contains("11:20") && born.label.contains("PM"), born.label)
		born.tap()
		XCTAssertEqual(app.switches["editor.birthTime"].value as? String, "1")
	}

	func testEditPhotoReframeAndPersist() {
		launch(seed: .pinned)
		overview.tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.buttons["editor.save"].isEnabled)
		choosePhoto()
		checkpoint("photo-controls")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("main-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		let reframe = app.buttons["editor.widgetPhoto.reframe"]
		XCTAssertTrue(reframe.isEnabled)
		reframe.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("widget-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForNonExistence(timeout: 5))
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		relaunch()
		checkpoint("saved-photo")
		overview.tap()
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.buttons["editor.save"].isEnabled)
		checkpoint("saved-photos-form")
		app.buttons["editor.appPhoto"].tap()
		let remove = app.buttons["photo.source.remove"]
		XCTAssertTrue(remove.waitForExistence(timeout: 5))
		checkpoint("image-menu-existing")
		remove.tap()
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.buttons["editor.save"].isEnabled)
		app.buttons["editor.appPhoto"].tap()
		XCTAssertTrue(app.buttons["photo.source.photos"].waitForExistence(timeout: 5))
		XCTAssertFalse(remove.exists)
		checkpoint("image-menu-removed")
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
		dismissPhotos()
		cancelEditor(discarding: true)
		overview.tap()
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.buttons["editor.save"].isEnabled)
	}

	func testCancelAndRecoverFromSaveFailure() {
		launch(failSave: true)
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5))
		name.tap()
		name.typeText("Ada")
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
		app.alerts.buttons.firstMatch.tap()
		XCTAssertTrue(app.buttons["editor.save"].isEnabled)
		app.buttons["editor.save"].tap()
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		overview.tap()
		let draftName = app.textFields["editor.name"]
		XCTAssertTrue(draftName.waitForExistence(timeout: 5))
		draftName.tap()
		draftName.typeText(" Unsaved\n")
		choosePhoto()
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.cancel"].waitForExistence(timeout: 5))
		app.buttons["crop.cancel"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
		dismissPhotos()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.images["editor.appPhoto.loaded"].exists)
		cancelEditor(discarding: true)
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		relaunch()
		waitForSettledOverview(showing: "Ada")
		checkpoint("cancelled-photo")
	}

	func testRussianCountdownPhotoAndPinLimit() {
		launch(seed: .sixPinned, locale: "ru", appearance: .dark, widgetFamily: "large")
		assertWidgetCaptions(locale: "ru")
		checkpoint("widget-large-ru-Dark")
		app.terminate()
		launch(seed: .birthdays, locale: "ru", appearance: .dark, clock: "2027-01-02T08:00:00Z")
		XCTAssertTrue(app.staticTexts["birthday.countdown"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["birthday.countdown"].label, "До дня рождения: 14 дней")
		checkpoint("birthday-countdown-days-ru")
		app.terminate()
		launch(seed: .sixPinned, locale: "ru", appearance: .dark)
		app.open(URL(string: "growingup-app://?personIndex=5")!)
		XCTAssertTrue(waitForName("Farah"))
		assertSeventhPinRejected(message: "В виджет можно добавить не больше 6 человек.", checkpoint: "widget-limit-ru")
		checkpoint("form-ru-Dark")
		choosePhoto()
		checkpoint("photo-ru-Dark")
	}

	func testHomeScreenWidgetSizes() {
		let names = ["Alice", "Boris", "Clara", "Daria", "Evan", "Farah"]
		for (family, count, appearance) in [("small", 1, UITestAppearance.light), ("medium", 3, .dark), ("large", 6, .light)] {
			launch(seed: .sixPinned, appearance: appearance, widgetFamily: family)
			for (index, name) in names.enumerated() {
				let person = widgetTile(name)
				if index < count {
					XCTAssertTrue(person.waitForExistence(timeout: 5), "\(family): \(name)")
				} else {
					XCTAssertFalse(person.exists, "\(family) should show only \(count) people")
				}
			}
			if family == "large" { assertWidgetCaptions(locale: "en") }
			checkpoint("widget-\(family)-en-\(appearance.launchArgumentValue)")
			app.terminate()
		}
	}

	private func assertSeventhPinRejected(message: String, checkpoint name: String) {
		app.swipeLeft()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		app.buttons["person.add"].tap()
		let field = app.textFields["editor.name"]
		XCTAssertTrue(field.waitForExistence(timeout: 5))
		field.tap()
		// Return dismisses the keyboard so it cannot cover the chips.
		field.typeText("Seventh\n")
		let pin = chip("editor.pin")
		XCTAssertEqual(pin.value as? String, "0")
		pin.tap()
		XCTAssertEqual(pin.value as? String, "1")
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
		XCTAssertTrue(app.alerts.staticTexts[message].exists)
		checkpoint(name)
		app.alerts.buttons.firstMatch.tap()
		XCTAssertTrue(app.buttons["editor.save"].isEnabled)
	}

	func testDeleteAndRelaunch() {
		launch()
		addPerson()
		overview.tap()
		let menu = app.buttons["editor.menu"]
		XCTAssertTrue(menu.waitForExistence(timeout: 5))
		menu.tap()
		let remove = app.buttons["editor.remove"]
		XCTAssertTrue(remove.waitForExistence(timeout: 5))
		remove.tap()
		let confirmation = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Remove", "editor.remove")).firstMatch
		XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
		confirmation.tap()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		relaunch()
		XCTAssertTrue(app.buttons["person.add"].exists)
		checkpoint("deleted")
	}

}

extension JourneyTests {
	private func launch(
		seed: UITestSeed = .empty, failSave: Bool = false, locale: String = "en", appearance: UITestAppearance = .light,
		widgetFamily: String? = nil, clock: String? = nil
	) {
		configuration = UITestConfiguration(
			identifier: UUID(uuidString: identifier)!, resetStore: true, seed: seed, failNextSave: failSave,
			appearance: appearance)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"TZ": "UTC"
		]
		if let widgetFamily { app.launchEnvironment["GROWINGUP_WIDGET_PREVIEW"] = widgetFamily }
		if let clock { app.launchEnvironment["GROWINGUP_BIRTHDAY_NOW"] = clock }
		app.launchArguments = [
			"-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ru" ? "ru_RU" : "en_US",
			"-AppleInterfaceStyle", appearance.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		if widgetFamily != nil {
			XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "widget.preview").firstMatch.waitForExistence(timeout: 10))
		} else {
			XCTAssertTrue((seed == .empty ? app.buttons["person.add"] : overview).waitForExistence(timeout: 10))
		}
	}

	private func widgetTile(_ name: String) -> XCUIElement {
		app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
	}

	/// The seed gives Alice 5 years and 3 months, Daria her birthday today and Evan his birthday in three days.
	private func assertWidgetCaptions(locale: String) {
		let russian = locale == "ru"
		let expectations = [
			("Alice", russian ? "5 лет" : "5 years, 3 months"),
			("Daria", russian ? "Сегодня день рождения" : "Birthday today"),
			("Evan", russian ? "День рождения через 3 дня" : "Birthday in 3 days")
		]
		for (name, text) in expectations {
			let label = widgetTile(name).label
			XCTAssertTrue(label.contains(text), "\(name): \(label)")
		}
	}

	private func relaunch() {
		app.terminate()
		configuration = configuration.forRelaunch()
		app.launchEnvironment[UITestConfiguration.environmentKey] = configuration.encoded
		app.launch()
		let page = app.descendants(matching: .any).matching(
			NSPredicate(format: "identifier == %@ OR identifier == %@", "person.edit", "person.add")
		).firstMatch
		XCTAssertTrue(page.waitForExistence(timeout: 5))
	}

	private func addPerson(birthPeriod: String = "AM", capturePickers: Bool = false) {
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5))
		name.tap()
		// Return dismisses the keyboard so it cannot cover the birthday row.
		name.typeText("Ada\n")
		if capturePickers {
			app.buttons["editor.birthDate"].tap()
			let date = app.datePickers["editor.birthDate.picker"]
			XCTAssertTrue(date.waitForExistence(timeout: 5))
			date.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "10")
			checkpoint("editor-date")
			let time = app.switches["editor.birthTime"]
			XCTAssertEqual(time.value as? String, "0")
			// The identifier belongs to the full toggle row; the native switch occupies its trailing edge.
			time.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
			XCTAssertEqual(time.value as? String, "1")
			let timePicker = app.datePickers["editor.birthTime.picker"]
			XCTAssertTrue(timePicker.waitForExistence(timeout: 5))
			timePicker.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "11")
			timePicker.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "20")
			// Adjusting the hour from midnight can roll the native wheel into the previous PM.
			timePicker.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: birthPeriod)
			let selectedTime = XCTNSPredicateExpectation(
				predicate: NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "11:20", birthPeriod),
				object: app.buttons["editor.birthDate"])
			XCTAssertEqual(XCTWaiter.wait(for: [selectedTime], timeout: 5), .completed)
			for wheel in timePicker.pickerWheels.allElementsBoundByIndex {
				XCTAssertTrue(wheel.isHittable, "The selected time must remain reachable after expanding the wheel")
			}
			checkpoint("editor-time")
			app.buttons["editor.birthDate"].tap()
		}
		app.buttons["editor.save"].tap()
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
	}

	/// Editor chips are buttons that report their state as a "1"/"0" value.
	private func chip(_ identifier: String) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	private func dismissPhotos() {
		let grabber = app.buttons["Sheet Grabber"].firstMatch
		XCTAssertTrue(grabber.waitForExistence(timeout: 5))
		grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
			forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
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

	private func choosePhoto() {
		app.buttons["editor.appPhoto"].tap()
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
	}

	/// Waits until the relaunched overview shows `name` with nothing presented over it, so the checkpoint
	/// cannot capture a launch or dismissal animation.
	private func waitForSettledOverview(showing name: String) {
		let personName = app.staticTexts["person.name"]
		let named = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", name), object: personName)
		let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: overview)
		XCTAssertEqual(XCTWaiter.wait(for: [named, hittable], timeout: 10), .completed)
		XCTAssertTrue(app.textFields["editor.name"].waitForNonExistence(timeout: 5))
		XCTAssertFalse(app.sheets.firstMatch.exists)
		XCTAssertFalse(app.alerts.firstMatch.exists)
	}

	private func waitForName(_ name: String) -> Bool {
		XCTWaiter.wait(
			for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", name), object: app.staticTexts["person.name"])], timeout: 5)
			== .completed
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
