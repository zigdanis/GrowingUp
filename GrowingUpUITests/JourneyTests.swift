import SnapshotTesting
import XCTest

@MainActor
final class JourneyTests: XCTestCase {
	private var app: XCUIApplication!
	private var identifier = UUID().uuidString

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
		identifier = UUID().uuidString
	}

	func testAddAndRelaunch() {
		launch()
		checkpoint("empty")
		addPerson()
		checkpoint("overview")
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
		app.buttons["person.edit"].tap()
		XCTAssertTrue(app.datePickers["editor.birthday"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.datePickers["editor.birthday"].buttons.firstMatch.label.contains("10"))
	}

	func testEditBothPhotosAndPersist() {
		launch()
		addPerson()
		app.buttons["person.edit"].tap()
		choosePhoto(slot: "appPhoto")
		checkpoint("photo-controls")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("main-crop")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
		choosePhoto(slot: "widgetPhoto")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("widget-crop")
		app.buttons["crop.use"].tap()
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["person.edit"].waitForExistence(timeout: 5))
		relaunch()
		checkpoint("saved-photo")
		app.buttons["person.edit"].tap()
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
		XCTAssertTrue(app.buttons["person.edit"].waitForExistence(timeout: 5))
		app.buttons["person.edit"].tap()
		let draftName = app.textFields["editor.name"]
		draftName.tap()
		draftName.typeText(" Unsaved")
		choosePhoto(slot: "appPhoto")
		app.buttons.matching(identifier: "photo.thumbnail").firstMatch.tap()
		XCTAssertTrue(app.buttons["crop.cancel"].waitForExistence(timeout: 5))
		app.buttons["crop.cancel"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
		app.swipeDown()
		XCTAssertTrue(app.buttons["editor.cancel"].waitForExistence(timeout: 5))
		app.buttons["editor.cancel"].tap()
		relaunch()
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
		checkpoint("cancelled-photo")
	}

	func testPinLimitAndWidgetLink() {
		launch(seed: "pinned")
		XCTAssertTrue(app.buttons["person.edit"].waitForExistence(timeout: 5))
		app.open(URL(string: "growingup-app://?personIndex=1")!)
		XCTAssertTrue(app.staticTexts["person.name"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["person.name"].label, "Boris")
		checkpoint("widget-link")
		app.swipeLeft()
		app.swipeLeft()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		name.tap()
		name.typeText("Fourth")
		app.switches["editor.pin"].tap()
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
		app.alerts.buttons.firstMatch.tap()
		XCTAssertTrue(app.buttons["editor.save"].isEnabled)
	}

	func testDeleteAndRelaunch() {
		launch()
		addPerson()
		app.buttons["person.edit"].tap()
		app.buttons["editor.remove"].tap()
		app.buttons["Remove"].lastMatch.tap()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		relaunch()
		XCTAssertTrue(app.buttons["person.add"].exists)
		checkpoint("deleted")
	}

	func testLocalizedPhotoAppearance() {
		for locale in ["en", "ru"] {
			for appearance in ["Light", "Dark"] {
				launch(locale: locale, appearance: appearance)
				app.buttons["person.add"].tap()
				XCTAssertTrue(app.textFields["editor.name"].waitForExistence(timeout: 5))
				checkpoint("form-\(locale)-\(appearance)")
				choosePhoto(slot: "appPhoto")
				checkpoint("photo-\(locale)-\(appearance)")
				app.terminate()
			}
		}
	}

	private func launch(seed: String = "", failSave: Bool = false, locale: String = "en", appearance: String = "Light") {
		app.launchEnvironment = [
			"GROWINGUP_UI_TEST_ID": identifier, "GROWINGUP_UI_RESET": "1", "GROWINGUP_UI_SEED": seed,
			"GROWINGUP_UI_FAIL_SAVE": failSave ? "1" : "0", "TZ": "UTC"
		]
		app.launchArguments = [
			"-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ru" ? "ru_RU" : "en_US",
			"-AppleInterfaceStyle", appearance, "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(app.buttons[seed.isEmpty ? "person.add" : "person.edit"].waitForExistence(timeout: 10))
	}

	private func relaunch() {
		app.terminate()
		app.launchEnvironment["GROWINGUP_UI_RESET"] = "0"
		app.launchEnvironment["GROWINGUP_UI_FAIL_SAVE"] = "0"
		app.launch()
		XCTAssertTrue(app.buttons["person.edit"].waitForExistence(timeout: 5) || app.buttons["person.add"].exists)
	}

	private func addPerson() {
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5))
		name.tap()
		name.typeText("Ada")
		let date = app.datePickers["editor.birthday"]
		date.buttons.firstMatch.tap()
		app.buttons["10"].tap()
		app.tap()
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["person.edit"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["person.name"].label, "Ada")
	}

	private func choosePhoto(slot: String) {
		app.buttons["editor.\(slot)"].tap()
		app.buttons["photo.source.photos"].tap()
		XCTAssertTrue(app.buttons.matching(identifier: "photo.thumbnail").firstMatch.waitForExistence(timeout: 5))
	}

	private func checkpoint(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
		let screenshot = app.screenshot()
		let attachment = XCTAttachment(screenshot: screenshot)
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
		// Compatibility runs assert behavior; exact visual baselines are scoped to the pinned glass runtime.
		guard ProcessInfo.processInfo.environment["GROWINGUP_VISUAL_CHECKS"] == "1" else { return }
		let recording = ProcessInfo.processInfo.environment["GROWINGUP_RECORD_SNAPSHOTS"] == "1"
		let failure = verifySnapshot(
			of: screenshot.image, as: .image(precision: 0.995, perceptualPrecision: 0.98), named: name,
			record: recording ? .all : .never, file: file, testName: "iOS26_5-iPhone17Pro-arm64", line: line)
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
