import XCTest

@MainActor
final class JourneyTests: XCTestCase {
	private var app: XCUIApplication!
	private var identifier = UUID().uuidString
	private var configuration: UITestConfiguration!

	/// The shown person in the full-screen viewer; a tap on it turns the viewer into its edit mode.
	private var overview: XCUIElement { app.buttons["person.name"] }
	private var tiles: XCUIElementQuery { app.buttons.matching(identifier: "people.tile") }

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
		checkpoint("mosaic-one-person")
		relaunch()
		openPerson("Ada")
		checkpoint("overview")
		overview.tap()
		let born = app.buttons["editor.birthDate"]
		XCTAssertTrue(born.waitForExistence(timeout: 5))
		XCTAssertEqual(born.value as? String, "Jan 10, 2027")
		let time = app.buttons["editor.birthTime"].value as? String ?? ""
		XCTAssertTrue(time.contains("11:20") && time.contains("PM"), time)
	}

	func testEditPhotoReframeAndPersist() {
		launch(seed: .pinned)
		openEditor(of: "Alice")
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.buttons["editor.save"].isEnabled)
		choosePhoto()
		checkpoint("photo-controls")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("main-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 5))
		// The widget picture's round control shows it and opens its circular crop.
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
		openEditor(of: "Alice")
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
		XCTAssertTrue(app.buttons["editor.widgetPhoto.reframe"].waitForNonExistence(timeout: 5), "No widget picture without a photo")
		XCTAssertTrue(app.buttons["editor.save"].isEnabled)
		app.buttons["editor.appPhoto"].tap()
		XCTAssertTrue(app.buttons["photo.source.photos"].waitForExistence(timeout: 5))
		XCTAssertFalse(remove.exists)
		checkpoint("image-menu-removed")
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
		dismissPhotos()
		cancelEditor()
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
		openEditor(of: "Ada")
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
		cancelEditor()
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
		openPerson("Alice")
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
		let capacity = ["small": 1, "medium": 3, "large": 6]
		for (family, seed) in [("small", UITestSeed.sixPinned), ("medium", .sixPinned), ("large", .sixPinned), ("large", .fourPinned)] {
			let count = seed == .fourPinned ? 4 : capacity[family, default: 0]
			let appearance: UITestAppearance = family == "medium" || seed == .fourPinned ? .dark : .light
			launch(seed: seed, appearance: appearance, widgetFamily: family)
			for (index, name) in names.enumerated() {
				let person = widgetTile(name)
				if index < count {
					XCTAssertTrue(person.waitForExistence(timeout: 5), "\(family): \(name)")
				} else {
					XCTAssertFalse(person.exists, "\(family) should show only \(count) people")
				}
			}
			if count == 6 { assertWidgetCaptions(locale: "en") }
			if count == 4 { assertTwoByTwo(names.prefix(4).map { widgetTile($0).frame }) }
			checkpoint("widget-\(family)-\(count)-en-\(appearance.launchArgumentValue)")
			app.terminate()
		}
	}

	private func assertSeventhPinRejected(message: String, checkpoint name: String) {
		closeViewer()
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
		openEditor(of: "Ada")
		let remove = app.buttons["editor.remove"]
		XCTAssertTrue(remove.waitForExistence(timeout: 5))
		remove.tap()
		let confirmation = app.alerts.buttons["Remove"]
		XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
		confirmation.tap()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		XCTAssertTrue(overview.waitForNonExistence(timeout: 5), "Removing the shown person returns to the mosaic")
		XCTAssertEqual(tiles.count, 0)
		relaunch()
		XCTAssertTrue(app.buttons["person.add"].exists)
		XCTAssertEqual(tiles.count, 0)
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
			XCTAssertTrue((seed == .empty ? app.buttons["person.add"] : tiles.firstMatch).waitForExistence(timeout: 10))
		}
	}

	/// Four people fill a large widget as two equal rows of two, leaving no empty slot.
	private func assertTwoByTwo(_ frames: [CGRect]) {
		XCTAssertEqual(frames[0].minY, frames[1].minY, accuracy: 1)
		XCTAssertEqual(frames[2].minY, frames[3].minY, accuracy: 1)
		XCTAssertGreaterThanOrEqual(frames[2].minY, frames[0].maxY)
		XCTAssertEqual(frames[0].minX, frames[2].minX, accuracy: 1)
		XCTAssertEqual(frames[1].minX, frames[3].minX, accuracy: 1)
		XCTAssertGreaterThan(frames[1].minX, frames[0].midX, "The second column starts right of the first")
		for frame in frames {
			XCTAssertEqual(frame.width, frames[0].width, accuracy: 1)
			XCTAssertEqual(frame.height, frames[0].height, accuracy: 1)
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
		// Launch always shows the mosaic, whose add button is there whether or not anyone was added.
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		XCTAssertFalse(overview.exists)
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
		// A new person lands on the mosaic as a new tile.
		XCTAssertTrue(tile("Ada").waitForExistence(timeout: 5))
		XCTAssertFalse(overview.exists)
	}

	private func tile(_ name: String) -> XCUIElement {
		tiles.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
	}

	/// Opens `name` from the mosaic in the full-screen viewer.
	private func openPerson(_ name: String) {
		XCTAssertTrue(tile(name).waitForExistence(timeout: 5))
		// Once the editor has closed, iPhone Duo keeps an empty window over the app that XCTest takes as covering the tile, so
		// a plain tap lands on its rounded corner; a real touch at its centre passes through to it.
		tile(name).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		XCTAssertTrue(waitForName(name))
	}

	/// Opens `name` from the mosaic and taps the viewer once the zoom settles, which turns it into its edit mode.
	private func openEditor(of name: String) {
		openPerson(name)
		let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: overview)
		XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
		overview.tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
	}

	/// Drags the viewer down, which zooms it back into the shown person's tile.
	private func closeViewer() {
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).press(
			forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
		XCTAssertTrue(overview.waitForNonExistence(timeout: 5))
	}

	/// Editor chips and edit-mode switches are buttons that report their state as a "1"/"0" value.
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

	/// Cancels the editor; unsaved changes are dropped without a confirmation.
	private func cancelEditor() {
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
	}

	private func choosePhoto() {
		app.buttons["editor.appPhoto"].tap()
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
	}

	/// Waits until the relaunched mosaic shows `name`'s tile with nothing presented over it, so the checkpoint
	/// cannot capture a launch or dismissal animation.
	private func waitForSettledOverview(showing name: String) {
		let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: tile(name))
		XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 10), .completed)
		XCTAssertTrue(app.textFields["editor.name"].waitForNonExistence(timeout: 5))
		XCTAssertFalse(app.sheets.firstMatch.exists)
		XCTAssertFalse(app.alerts.firstMatch.exists)
	}

	private func waitForName(_ name: String) -> Bool {
		XCTWaiter.wait(
			for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", name), object: app.buttons["person.name"])], timeout: 5)
			== .completed
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
