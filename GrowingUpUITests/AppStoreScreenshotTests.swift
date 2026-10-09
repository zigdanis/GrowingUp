import XCTest

/// Opt-in capture of the app's real editor, crops, saved people and WidgetKit content.
@MainActor
final class AppStoreScreenshotTests: XCTestCase {
	private var app = XCUIApplication()
	private var configuration: UITestConfiguration!
	private var locale = "en"
	private var names: [String] { locale == "ru" ? ["Мия", "Лео", "Манго", "Тедди"] : ["Mia", "Leo", "Mango", "Teddy"] }
	private var overview: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.edit").firstMatch }
	private var confetti: XCUIElement { app.descendants(matching: .any).matching(identifier: "person.confetti").firstMatch }

	func testCaptureAppStoreScreenshots() throws {
		let environment = ProcessInfo.processInfo.environment
		try XCTSkipUnless(environment["GROWINGUP_APP_STORE_CAPTURE"] == "1", "Run the dedicated App Store capture workflow.")
		continueAfterFailure = false
		locale = try XCTUnwrap(environment["GROWINGUP_APP_STORE_LOCALE"])
		XCTAssertTrue(["en", "ru"].contains(locale))
		let photos = try XCTUnwrap(environment["GROWINGUP_APP_STORE_PHOTOS"])
		launchCapture(photos: photos)
		// Dates are entered using the native wheel editor, never injected into persistence.
		addPerson(index: 0, year: 2026, month: 7, day: 16)
		addPerson(index: 1, year: 2021, month: 1, day: 16)
		addPerson(index: 2, year: 2024, month: 10, day: 16)
		addPerson(index: 3, year: 2026, month: 1, day: 15)
		verifyPersistence()
		capturePeople()
		captureWidgets()
		app.terminate()
	}

	private func launchCapture(photos: String) {
		configuration = UITestConfiguration(identifier: UUID(), resetStore: true, seed: .empty, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"GROWINGUP_APP_STORE_CAPTURE": "1", "GROWINGUP_APP_STORE_PHOTOS": photos,
			"GROWINGUP_BIRTHDAY_NOW": "2027-01-16T10:30:00Z", "TZ": "UTC"
		]
		app.launchArguments = [
			"-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ru" ? "ru_RU" : "en_US",
			"-AppleInterfaceStyle", "Dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 10))
	}

	private func verifyPersistence() {
		relaunch()
		for index in names.indices {
			selectPerson(index)
			overview.tap()
			XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 10))
			XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 10))
			XCTAssertEqual(app.switches["editor.pin"].value as? String, "1")
			checkpoint("store-\(locale)-persisted-\(index)")
			dismissEditor()
		}
	}

	private func capturePeople() {
		selectPerson(0)
		checkpoint("store-\(locale)-mia")
		selectPerson(2)
		checkpoint("store-\(locale)-mango")
		selectPerson(3)
		checkpoint("store-\(locale)-teddy")
		// Navigate and open the popover before midnight so XCTest synchronization cannot consume the burst.
		app.launchEnvironment["GROWINGUP_BIRTHDAY_NOW"] = "2027-01-15T23:59:20Z"
		app.launchEnvironment["GROWINGUP_BIRTHDAY_CLOCK_RUNNING"] = "1"
		relaunch()
		selectPerson(1)
		app.buttons["person.birthday"].tap()
		XCTAssertTrue(confetti.waitForExistence(timeout: 60), "The production midnight transition must start the birthday animation.")
		// The production birthday popover demonstrates native Liquid Glass while the burst is running.
		checkpoint("store-\(locale)-leo-celebration")
		checkpoint("store-\(locale)-leo-celebration-frame-2")
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.staticTexts[locale == "ru" ? "С днём рождения!" : "Happy birthday!"].exists)
		XCTAssertFalse(app.staticTexts["birthday.countdown"].exists)
		checkpoint("store-\(locale)-birthday-confirmed")
		app.launchEnvironment["GROWINGUP_BIRTHDAY_NOW"] = "2027-01-16T10:30:00Z"
		app.launchEnvironment["GROWINGUP_BIRTHDAY_CLOCK_RUNNING"] = "0"
	}

	private func captureWidgets() {
		for (family, count) in [("small", 1), ("medium", 3), ("large", 4)] {
			relaunch(widgetFamily: family)
			let widget = app.descendants(matching: .any).matching(identifier: "widget.preview").firstMatch
			XCTAssertTrue(widget.waitForExistence(timeout: 10))
			for (index, name) in names.enumerated() {
				let person = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
				if index < count {
					XCTAssertTrue(person.waitForExistence(timeout: 5))
				} else {
					XCTAssertFalse(person.exists)
				}
			}
			checkpoint("store-\(locale)-widget-\(family)", element: widget)
		}
	}

	private func addPerson(index: Int, year: Int, month: Int, day: Int) {
		if index > 0 { app.swipeLeft() }
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5))
		name.tap()
		name.typeText(names[index])
		app.buttons["editor.birthDate"].tap()
		let picker = app.datePickers["editor.birthDate.picker"]
		XCTAssertTrue(picker.waitForExistence(timeout: 5))
		let wheels = picker.pickerWheels
		XCTAssertEqual(wheels.count, 3)
		wheels.element(boundBy: 2).adjust(toPickerWheelValue: String(year))
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: locale == "ru" ? "ru_RU" : "en_US")
		let monthName = formatter.monthSymbols[month - 1].capitalized(with: formatter.locale)
		wheels.element(boundBy: locale == "ru" ? 1 : 0).adjust(toPickerWheelValue: monthName)
		wheels.element(boundBy: locale == "ru" ? 0 : 1).adjust(toPickerWheelValue: String(day))
		app.buttons["editor.birthDate"].tap()
		XCTAssertEqual(app.switches["editor.pin"].value as? String, "1")
		for slot in ["appPhoto", "widgetPhoto"] {
			app.buttons["editor.\(slot)"].tap()
			app.buttons["photo.source.photos"].tap()
			let thumbnails = app.buttons.matching(identifier: "photo.thumbnail")
			XCTAssertTrue(thumbnails.firstMatch.waitForExistence(timeout: 5))
			XCTAssertEqual(thumbnails.count, 4)
			thumbnails.element(boundBy: index).tap()
			XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
			checkpoint("store-\(locale)-crop-\(index)-\(slot)")
			app.buttons["crop.use"].tap()
			XCTAssertTrue(thumbnails.firstMatch.waitForNonExistence(timeout: 5))
			XCTAssertTrue(app.images["editor.\(slot).loaded"].waitForExistence(timeout: 10))
		}
		app.buttons["editor.save"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 10))
		XCTAssertTrue(overview.waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["person.name"].label, names[index])
	}

	private func relaunch(widgetFamily: String? = nil) {
		app.terminate()
		configuration = configuration.forRelaunch()
		app.launchEnvironment[UITestConfiguration.environmentKey] = configuration.encoded
		app.launchEnvironment["GROWINGUP_WIDGET_PREVIEW"] = widgetFamily
		app.launch()
		if widgetFamily == nil { XCTAssertTrue(overview.waitForExistence(timeout: 10)) }
	}

	private func selectPerson(_ index: Int) {
		app.open(URL(string: "growingup-app://?personIndex=\(index)")!)
		let name = app.staticTexts["person.name"]
		let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", names[index]), object: name)
		XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
	}

	private func dismissEditor() {
		let navigation = app.navigationBars.firstMatch
		let start = navigation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
		start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
	}

	private func checkpoint(_ name: String, element: XCUIElement? = nil) {
		let attachment = XCTAttachment(screenshot: element?.screenshot() ?? app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
