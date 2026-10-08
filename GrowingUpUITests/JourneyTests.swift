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
		XCTAssertTrue(app.buttons["editor.birthDate"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.buttons["editor.birthDate"].label.contains("Jan 10, 2027"))
		XCTAssertTrue(app.buttons["editor.birthTime"].label.contains("11:20"))
	}

	func testEditBothPhotosAndPersist() {
		launch()
		addPerson()
		overview.tap()
		choosePhoto(slot: "appPhoto")
		checkpoint("photo-controls")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("main-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		choosePhoto(slot: "widgetPhoto")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("widget-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
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
		draftName.tap()
		draftName.typeText(" Unsaved")
		choosePhoto(slot: "appPhoto")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.cancel"].waitForExistence(timeout: 5))
		app.buttons["crop.cancel"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
		dismissPhotos()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		dismissEditor()
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
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
			XCTAssertEqual(app.switches["editor.pin"].value as? String, "1")
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
		XCTAssertEqual(app.switches["editor.pin"].value as? String, "1")
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
			for (family, count) in [("small", 1), ("medium", 3), ("large", 6)] {
				launch(seed: .sixPinned, locale: locale, widgetFamily: family)
				for (index, name) in names.enumerated() {
					let person = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
					if index < count {
						XCTAssertTrue(person.waitForExistence(timeout: 5), "\(family): \(name)")
					} else {
						XCTAssertFalse(person.exists, "\(family) should show only \(count) people")
					}
				}
				checkpoint("widget-\(family)-\(locale)", compareBaseline: false)
				app.terminate()
			}
		}
	}

	private func assertSeventhPinRejected(message: String, checkpoint name: String) {
		app.swipeLeft()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		app.buttons["person.add"].tap()
		let field = app.textFields["editor.name"]
		XCTAssertTrue(field.waitForExistence(timeout: 5))
		field.tap()
		field.typeText("Seventh")
		let pin = app.switches["editor.pin"]
		XCTAssertEqual(pin.value as? String, "0")
		// The identifier belongs to the full form row; the native switch occupies its trailing edge.
		pin.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
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
		app.buttons["editor.remove"].tap()
		app.sheets.buttons["Remove"].tap()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		relaunch()
		XCTAssertTrue(app.buttons["person.add"].exists)
		checkpoint("deleted")
	}

	func testPhotoRemovalMenuTracksEachImage() {
		launch()
		app.buttons["person.add"].tap()
		for slot in ["appPhoto", "widgetPhoto"] {
			app.buttons["editor.\(slot)"].tap()
			XCTAssertTrue(app.buttons["photo.source.photos"].waitForExistence(timeout: 5))
			XCTAssertFalse(app.buttons["photo.source.remove"].exists)
			if slot == "appPhoto" { checkpoint("image-menu-empty") }
			app.buttons["photo.source.photos"].tap()
			XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
			app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
			XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
			app.buttons["crop.use"].tap()
			XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
			app.buttons["editor.\(slot)"].tap()
			XCTAssertTrue(app.buttons["photo.source.remove"].waitForExistence(timeout: 5))
			if slot == "appPhoto" { checkpoint("image-menu-existing") }
			app.buttons["photo.source.remove"].tap()
			XCTAssertTrue(app.buttons["photo.source.remove"].waitForNonExistence(timeout: 5))
			app.buttons["editor.\(slot)"].tap()
			XCTAssertTrue(app.buttons["photo.source.photos"].waitForExistence(timeout: 5))
			XCTAssertFalse(app.buttons["photo.source.remove"].exists)
			if slot == "appPhoto" { checkpoint("image-menu-removed") }
			app.buttons["photo.source.photos"].tap()
			XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
			dismissPhotos()
			XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		}
	}

	func testLocalizedPhotoAppearance() {
		for locale in ["en", "ru"] {
			for appearance in UITestAppearance.allCases {
				launch(locale: locale, appearance: appearance)
				app.buttons["person.add"].tap()
				XCTAssertTrue(app.textFields["editor.name"].waitForExistence(timeout: 5))
				checkpoint("form-\(locale)-\(appearance.launchArgumentValue)")
				choosePhoto(slot: "appPhoto")
				checkpoint("photo-\(locale)-\(appearance.launchArgumentValue)")
				app.terminate()
			}
		}
	}

}

extension JourneyTests {
	private func launch(
		seed: UITestSeed = .empty, failSave: Bool = false, locale: String = "en", appearance: UITestAppearance = .light,
		widgetFamily: String? = nil
	) {
		configuration = UITestConfiguration(
			identifier: UUID(uuidString: identifier)!, resetStore: true, seed: seed, failNextSave: failSave,
			appearance: appearance)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"TZ": "UTC"
		]
		if let widgetFamily { app.launchEnvironment["GROWINGUP_WIDGET_PREVIEW"] = widgetFamily }
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
		name.typeText("Ada")
		app.buttons["editor.birthDate"].tap()
		let date = app.datePickers["editor.birthDate.picker"]
		XCTAssertTrue(date.waitForExistence(timeout: 5))
		date.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "10")
		if capturePickers { checkpoint("editor-date") }
		app.buttons["editor.birthTime"].tap()
		let time = app.datePickers["editor.birthTime.picker"]
		XCTAssertTrue(time.waitForExistence(timeout: 5))
		time.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "11")
		time.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "20")
		if capturePickers { checkpoint("editor-time") }
		app.buttons["editor.birthTime"].tap()
		app.buttons["editor.save"].tap()
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
	}

	private func dismissPhotos() {
		let grabber = app.buttons["Sheet Grabber"].firstMatch
		XCTAssertTrue(grabber.waitForExistence(timeout: 5))
		grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
			forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForNonExistence(timeout: 5))
	}

	private func dismissEditor() {
		// Drag from the sheet's navigation area, avoiding scrolling the form or dismissing only the keyboard.
		let navigationBar = app.navigationBars.firstMatch
		XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
		let start = navigationBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
		let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
		start.press(forDuration: 0.1, thenDragTo: end)
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
	}

	private func choosePhoto(slot: String) {
		app.buttons["editor.\(slot)"].tap()
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
	}

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
