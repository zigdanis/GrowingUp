import SnapshotTesting
import UIKit
import XCTest

@MainActor
final class JourneyTests: XCTestCase {
	private var app: XCUIApplication!
	private var identifier = UUID().uuidString
	private var configuration: UITestConfiguration!

	private var overview: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.edit").firstMatch }

	override func setUp() {
		super.setUp()
		// SnapshotTesting reports each deliberate recording as a failure after writing the image.
		// Continue only in explicit recording runs so all checkpoints are generated; functional failures remain reported.
		continueAfterFailure = ProcessInfo.processInfo.environment["GROWINGUP_RECORD_SNAPSHOTS"] == "1"
		app = XCUIApplication()
		identifier = UUID().uuidString
	}

	func testAddAndRelaunch() {
		launch()
		checkpoint("empty")
		addPerson(capturePickers: true)
		checkpoint("overview")
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
		overview.tap()
		let born = app.buttons["editor.birthDate"]
		XCTAssertTrue(born.waitForExistence(timeout: 5))
		XCTAssertTrue(born.label.contains("January 10, 2027"), born.label)
		XCTAssertTrue(born.label.contains("11:20"), born.label)
		born.tap()
		XCTAssertEqual(app.switches["editor.birthTime"].value as? String, "1")
	}

	func testEditPhotoReframeAndPersist() {
		launch()
		addPerson()
		overview.tap()
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
		checkpoint("saved-photos-form")
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

	func testSixPinsPersistAndWidgetLinkSelectsSixthPerson() {
		launch(seed: .pinned)
		app.open(URL(string: "growingup-app://?personIndex=1")!)
		XCTAssertTrue(app.staticTexts["person.name"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["person.name"].label, "Boris")
		checkpoint("widget-link")
		app.open(URL(string: "growingup-app://?personIndex=2")!)
		XCTAssertEqual(app.staticTexts["person.name"].label, "Clara")
		for name in ["Fourth", "Fifth", "Sixth"] {
			app.swipeLeft()
			XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
			app.buttons["person.add"].tap()
			let field = app.textFields["editor.name"]
			XCTAssertTrue(field.waitForExistence(timeout: 5))
			field.tap()
			field.typeText(name)
			XCTAssertEqual(chip("editor.pin").value as? String, "1")
			app.buttons["editor.save"].tap()
			XCTAssertTrue(overview.waitForExistence(timeout: 5))
			XCTAssertEqual(app.staticTexts["person.name"].label, name)
		}
		relaunch()
		app.open(URL(string: "growingup-app://?personIndex=5")!)
		XCTAssertEqual(app.staticTexts["person.name"].label, "Sixth")
		checkpoint("widget-sixth-link", compareBaseline: false)
		// Editing an already pinned person still works when all six slots are occupied.
		overview.tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		XCTAssertEqual(chip("editor.pin").value as? String, "1")
		XCTAssertFalse(app.buttons["editor.save"].isEnabled)
		let sixthName = app.textFields["editor.name"]
		sixthName.tap()
		sixthName.typeText(" Updated")
		app.buttons["editor.save"].tap()
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		assertSeventhPinRejected(message: "You can pin up to 6 people to the widget.", checkpoint: "widget-limit-en")
	}

	func testSeventhPinErrorIsLocalizedInRussian() {
		launch(seed: .sixPinned, locale: "ru")
		app.open(URL(string: "growingup-app://?personIndex=5")!)
		XCTAssertEqual(app.staticTexts["person.name"].label, "Farah")
		assertSeventhPinRejected(message: "В виджет можно добавить не больше 6 человек.", checkpoint: "widget-limit-ru")
	}

	func testWidgetSizesRenderPinnedPeopleInBothLanguages() {
		let names = ["Alice", "Boris", "Clara", "Daria", "Evan", "Farah"]
		for locale in ["en", "ru"] {
			for appearance in UITestAppearance.allCases {
				for (family, count) in [("small", 1), ("medium", 3), ("large", 6)] {
					launch(seed: .sixPinned, locale: locale, appearance: appearance, widgetFamily: family)
					for (index, name) in names.enumerated() {
						let person = widgetTile(name)
						if index < count {
							XCTAssertTrue(person.waitForExistence(timeout: 5), "\(family): \(name)")
						} else {
							XCTAssertFalse(person.exists, "\(family) should show only \(count) people")
						}
					}
					if family == "large" { assertWidgetCaptions(locale: locale) }
					checkpoint("widget-\(family)-\(locale)-\(appearance.launchArgumentValue)", compareBaseline: false)
					app.terminate()
				}
			}
			// Lock Screen widgets keep the Lock Screen's look whatever the app appearance, so they render once per language.
			for family in ["circular", "rectangular", "inline"] {
				launch(seed: .sixPinned, locale: locale, widgetFamily: family)
				XCTAssertTrue(widgetTile("Alice").waitForExistence(timeout: 5), family)
				XCTAssertFalse(widgetTile("Boris").exists, "\(family) should show only the first person")
				checkpoint("widget-\(family)-\(locale)", compareBaseline: false)
				app.terminate()
			}
		}
	}

	func testLockScreenWidgetsCelebrateTheFirstPinnedBirthday() {
		// Alice, the first pinned person, was born on 16 January 2020.
		for (family, expected) in [("circular", "Birthday today"), ("rectangular", "Birthday today"), ("inline", "turns 7 today")] {
			launch(seed: .birthdays, widgetFamily: family, clock: "2027-01-16T08:00:00Z")
			let alice = widgetTile("Alice")
			XCTAssertTrue(alice.waitForExistence(timeout: 5), family)
			XCTAssertTrue(alice.label.contains(expected), "\(family): \(alice.label)")
			checkpoint("widget-\(family)-birthday-en", compareBaseline: false)
			app.terminate()
		}
		launch(seed: .birthdays, locale: "ru", widgetFamily: "rectangular", clock: "2027-01-16T08:00:00Z")
		let russianAlice = widgetTile("Alice")
		XCTAssertTrue(russianAlice.waitForExistence(timeout: 5))
		XCTAssertTrue(russianAlice.label.contains("Сегодня день рождения"), russianAlice.label)
		checkpoint("widget-rectangular-birthday-ru", compareBaseline: false)
		app.terminate()
	}

	func testLockScreenWidgetsInviteToAddSomeoneWhenNobodyIsPinned() {
		for family in ["circular", "rectangular", "inline"] {
			launch(seed: .empty, widgetFamily: family)
			let invitation = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Add someone")).firstMatch
			XCTAssertTrue(invitation.waitForExistence(timeout: 5), family)
			checkpoint("widget-\(family)-empty-en", compareBaseline: false)
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
		checkpoint(name, compareBaseline: false)
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

	func testPhotoRemovalMenuTracksEachImage() {
		launch()
		app.buttons["person.add"].tap()
		let menu = app.buttons["editor.appPhoto"]
		let remove = app.buttons["photo.source.remove"]
		let thumbnail = app.buttons.matching(identifier: "photo.thumbnail").firstMatch
		XCTAssertTrue(menu.waitForExistence(timeout: 5))
		menu.tap()
		XCTAssertTrue(app.buttons["photo.source.photos"].waitForExistence(timeout: 5))
		XCTAssertFalse(remove.exists)
		settleMenu()
		checkpoint("image-menu-empty")
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(thumbnail.waitForExistence(timeout: 5))
		thumbnail.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		app.buttons["crop.use"].tap()
		XCTAssertTrue(thumbnail.waitForNonExistence(timeout: 5))
		// The widget picture is derived from the new main photo.
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 5))
		menu.tap()
		XCTAssertTrue(remove.waitForExistence(timeout: 5))
		settleMenu()
		checkpoint("image-menu-existing")
		remove.tap()
		XCTAssertTrue(remove.waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForNonExistence(timeout: 5))
		XCTAssertFalse(app.images["editor.appPhoto.loaded"].exists)
		menu.tap()
		XCTAssertTrue(app.buttons["photo.source.photos"].waitForExistence(timeout: 5))
		XCTAssertFalse(remove.exists)
		settleMenu()
		checkpoint("image-menu-removed")
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(thumbnail.waitForExistence(timeout: 5))
		dismissPhotos()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
	}

	func testLocalizedPhotoAppearance() {
		for locale in ["en", "ru"] {
			for appearance in UITestAppearance.allCases {
				launch(locale: locale, appearance: appearance)
				app.buttons["person.add"].tap()
				XCTAssertTrue(app.textFields["editor.name"].waitForExistence(timeout: 5))
				checkpoint("form-\(locale)-\(appearance.launchArgumentValue)")
				choosePhoto()
				checkpoint("photo-\(locale)-\(appearance.launchArgumentValue)")
				app.terminate()
			}
		}
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
		XCTAssertTrue(overview.waitForExistence(timeout: 5) || app.buttons["person.add"].exists)
	}

	private func addPerson(capturePickers: Bool = false) {
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5))
		name.tap()
		// Return dismisses the keyboard so it cannot cover the birthday row.
		name.typeText("Ada\n")
		app.buttons["editor.birthDate"].tap()
		let date = app.datePickers["editor.birthDate.picker"]
		XCTAssertTrue(date.waitForExistence(timeout: 5))
		date.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "10")
		if capturePickers { checkpoint("editor-date") }
		let time = app.switches["editor.birthTime"]
		XCTAssertEqual(time.value as? String, "0")
		// The identifier belongs to the full toggle row; the native switch occupies its trailing edge.
		time.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
		XCTAssertEqual(time.value as? String, "1")
		let timePicker = app.datePickers["editor.birthTime.picker"]
		XCTAssertTrue(timePicker.waitForExistence(timeout: 5))
		timePicker.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "11")
		timePicker.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "20")
		if capturePickers { checkpoint("editor-time") }
		app.buttons["editor.birthDate"].tap()
		app.buttons["editor.save"].tap()
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
	}

	/// Editor chips are buttons that report their state as a "1"/"0" value.
	private func chip(_ identifier: String) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	/// Lets the source menu finish its Liquid Glass morph so a checkpoint cannot capture it mid-animation.
	private func settleMenu() {
		Thread.sleep(forTimeInterval: 1)
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
		// A person born "today" on the fixed clock can still be playing the birthday burst after a relaunch.
		_ = confetti.waitForExistence(timeout: 3)
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 10))
		XCTAssertFalse(app.sheets.firstMatch.exists)
		XCTAssertFalse(app.alerts.firstMatch.exists)
	}

	private var confetti: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.confetti").firstMatch }

	private func checkpoint(_ name: String, compareBaseline: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
		let screenshot = app.screenshot()
		let attachment = XCTAttachment(screenshot: screenshot)
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
		// Compatibility runs assert behavior; exact visual baselines are scoped to the pinned glass runtime.
		guard compareBaseline, ProcessInfo.processInfo.environment["GROWINGUP_VISUAL_CHECKS"] == "1" else { return }
		let recording = ProcessInfo.processInfo.environment["GROWINGUP_RECORD_SNAPSHOTS"] == "1"
		let failure = verifySnapshot(
			of: screenshot.image, as: .image(precision: 0.995, perceptualPrecision: 0.98), named: name,
			record: recording ? .all : .never, file: file, testName: "iOS26_5-iPhone17Pro-arm64", line: line)
		// Export every changed checkpoint so intentional UI updates can be reviewed together.
		// Functional assertions retain the suite's normal stop-on-failure behavior.
		let previousContinueAfterFailure = continueAfterFailure
		continueAfterFailure = true
		defer { continueAfterFailure = previousContinueAfterFailure }
		if let failure { XCTFail(failure, file: file, line: line) }
		if name.hasPrefix("photo-") {
			// Compare the controls separately so a small opaque button cannot hide in a full-screen tolerance.
			let image = screenshot.image
			let pixels = image.cgImage!
			let height = min(pixels.height, Int(120 * image.scale))
			let region = pixels.cropping(to: CGRect(x: 0, y: pixels.height - height, width: pixels.width, height: height))!
			let controls = UIImage(cgImage: region, scale: image.scale, orientation: .up)
			let failure = verifySnapshot(
				of: controls, as: .image(precision: 0.995, perceptualPrecision: 0.98), named: "\(name)-controls-region",
				record: recording ? .all : .never, file: file, testName: "iOS26_5-iPhone17Pro-arm64", line: line)
			if let failure { XCTFail(failure, file: file, line: line) }
		}

	}
}
