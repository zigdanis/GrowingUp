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
	private var birthdayToday: String { locale == "ru" ? "Сегодня день рождения 🎂" : "Birthday today 🎂" }

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
		app.launchEnvironment["GROWINGUP_BIRTHDAY_NOW"] = "2027-01-16T08:24:12Z"
		verifyPersistence()
		capturePeople()
		captureWidgets()
		app.terminate()
	}

	/// Local, opt-in fixture preparation; it never touches the live App Group database.
	func testPrepareAppPreview() throws {
		try configurePreview(reset: true)
		addPerson(index: 0, year: 2026, month: 7, day: 16)
		addPerson(index: 1, year: 2023, month: 1, day: 16)
		addPerson(index: 2, year: 2024, month: 10, day: 16)
		addPerson(index: 3, year: 2026, month: 1, day: 15)
		verifyPersistence()
		selectPerson(0)
		previewMark("fixture-persisted")
	}

	/// A real-time pass through production UI. Host simctl captures the native screen.
	func testRecordAppPreview() throws {
		try recordPreview(expectNoConfetti: false)
	}

	func testRecordAppPreviewWithoutConfetti() throws {
		try recordPreview(expectNoConfetti: true)
	}

	private func recordPreview(expectNoConfetti: Bool) throws {
		try configurePreview(reset: false)
		XCTAssertEqual(app.staticTexts["person.name"].label, names[0])
		previewMark("ready")
		Thread.sleep(forTimeInterval: 5)
		previewMark("mia-start")
		Thread.sleep(forTimeInterval: 4)
		previewMark("leo-swipe")
		app.swipeLeft(velocity: .fast)
		previewMark("leo-arrived")
		if expectNoConfetti { XCTAssertFalse(confetti.exists, "Reduce Motion must suppress the real confetti before capture proceeds.") }
		previewMark("birthday-open")
		if expectNoConfetti { XCTAssertFalse(confetti.exists) }
		XCTAssertEqual(app.staticTexts["birthday.countdown"].label, birthdayToday)
		Thread.sleep(forTimeInterval: 4)
		previewMark("mango-swipe")
		app.swipeLeft(velocity: .fast)
		previewMark("mango-arrived")
		XCTAssertEqual(app.staticTexts["person.name"].label, names[2])
		Thread.sleep(forTimeInterval: 3.45)
		previewMark("teddy-swipe")
		app.swipeLeft(velocity: .fast)
		previewMark("teddy-arrived")
		XCTAssertEqual(app.staticTexts["person.name"].label, names[3])
		Thread.sleep(forTimeInterval: 3.45)
		previewMark("return-mia")
		for _ in 0..<3 { app.swipeRight(velocity: .fast) }
		previewMark("mia-returned")
		XCTAssertTrue(app.staticTexts.matching(identifier: "person.name").matching(NSPredicate(format: "label == %@", names[0])).firstMatch.exists)
		overview.tap()
		previewMark("editor-open")
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 5))
		// Make a genuine, keyboard-free change so the native save action is enabled.
		chip("editor.pin").tap()
		previewMark("editor-change")
		app.buttons["editor.save"].tap()
		previewMark("saved")
		Thread.sleep(forTimeInterval: 1.5)
		XCTAssertFalse(app.buttons["editor.save"].exists)
		previewMark("end")
		// Retain the prepared simulator in its main-card state for Danis.
	}

	private func configurePreview(reset: Bool) throws {
		let env = ProcessInfo.processInfo.environment
		try XCTSkipUnless(env["GROWINGUP_APP_STORE_CAPTURE"] == "1", "Opt-in local media capture")
		continueAfterFailure = false
		locale = try XCTUnwrap(env["GROWINGUP_APP_STORE_LOCALE"])
		XCTAssertTrue(["en", "ru"].contains(locale))
		let identifier = UUID(uuidString: locale == "ru" ? "D11D2026-1013-4000-8000-000000000002" : "D11D2026-1013-4000-8000-000000000001")!
		configuration = UITestConfiguration(identifier: identifier, resetStore: reset, seed: .empty, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"GROWINGUP_APP_STORE_CAPTURE": "1", "GROWINGUP_APP_STORE_PHOTOS": try XCTUnwrap(env["GROWINGUP_APP_STORE_PHOTOS"]),
			"GROWINGUP_BIRTHDAY_NOW": "2027-01-16T08:24:12Z", "GROWINGUP_BIRTHDAY_CLOCK_RUNNING": "1", "TZ": "UTC"
		]
		app.launchArguments = [
			"-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ru" ? "ru_RU" : "en_US",
			"-AppleInterfaceStyle", "Dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue((reset ? app.buttons["person.add"] : overview).waitForExistence(timeout: 10))
	}

	private func previewMark(_ scene: String) {
		print("PREVIEW_MARK \(scene) \(Date().timeIntervalSince1970)")
	}

	private func launchCapture(photos: String) {
		configuration = UITestConfiguration(identifier: UUID(), resetStore: true, seed: .empty, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"GROWINGUP_APP_STORE_CAPTURE": "1", "GROWINGUP_APP_STORE_PHOTOS": photos,
			"GROWINGUP_BIRTHDAY_NOW": "2027-01-16T00:00:00Z", "TZ": "UTC"
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
			XCTAssertEqual(chip("editor.pin").value as? String, "1")
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
		// Navigate before midnight so XCTest synchronization cannot consume the burst.
		app.launchEnvironment["GROWINGUP_BIRTHDAY_NOW"] = "2027-01-15T23:59:20Z"
		app.launchEnvironment["GROWINGUP_BIRTHDAY_CLOCK_RUNNING"] = "1"
		relaunch()
		selectPerson(1)
		XCTAssertTrue(confetti.waitForExistence(timeout: 60), "The production midnight transition must start the birthday animation.")
		// The production birthday card demonstrates native Liquid Glass while the burst is running.
		checkpoint("store-\(locale)-leo-celebration")
		checkpoint("store-\(locale)-leo-celebration-frame-2")
		XCTAssertTrue(confetti.waitForNonExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["birthday.countdown"].label, birthdayToday)
		checkpoint("store-\(locale)-birthday-confirmed")
		app.launchEnvironment["GROWINGUP_BIRTHDAY_NOW"] = "2027-01-16T08:24:12Z"
		app.launchEnvironment["GROWINGUP_BIRTHDAY_CLOCK_RUNNING"] = "0"
	}

	private func captureWidgets() {
		for (family, count) in [("small", 1), ("medium", 3), ("large", 4)] {
			relaunch(widgetFamily: family)
			let widget = app.otherElements.matching(identifier: "widget.preview").firstMatch
			XCTAssertTrue(widget.waitForExistence(timeout: 10))
			let nominal = CGSize(width: family == "small" ? 170 : 364, height: family == "large" ? 382 : 170)
			// iPhone Duo's accessibility frame can extend past the drawn widget; the capture crops it to the real size.
			XCTAssertGreaterThanOrEqual(widget.frame.width, nominal.width - 0.5)
			XCTAssertGreaterThanOrEqual(widget.frame.height, nominal.height - 0.5)
			for (index, name) in names.enumerated() {
				let person = widget.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
				if index < count {
					XCTAssertTrue(person.waitForExistence(timeout: 5))
				} else {
					XCTAssertFalse(person.exists)
				}
			}
			checkpoint("store-\(locale)-widget-\(family)", element: widget, croppedTo: nominal)
		}
	}

	private func addPerson(index: Int, year: Int, month: Int, day: Int) {
		if index > 0 { app.swipeLeft() }
		XCTAssertTrue(app.buttons["person.add"].waitForExistence(timeout: 5))
		app.buttons["person.add"].tap()
		let name = app.textFields["editor.name"]
		XCTAssertTrue(name.waitForExistence(timeout: 5))
		name.tap()
		// Return dismisses the keyboard so it cannot cover the birthday row.
		name.typeText(names[index] + "\n")
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
		XCTAssertEqual(chip("editor.pin").value as? String, "1")
		app.buttons["editor.appPhoto"].tap()
		app.buttons["photo.source.photos"].tap()
		let thumbnails = app.buttons.matching(identifier: "photo.thumbnail")
		XCTAssertTrue(thumbnails.firstMatch.waitForExistence(timeout: 5))
		XCTAssertEqual(thumbnails.count, 4)
		thumbnails.element(boundBy: index).tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("store-\(locale)-crop-\(index)-appPhoto")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(thumbnails.firstMatch.waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 10))
		// The widget picture is derived from the main photo; reframing shows its circular crop.
		app.buttons["editor.widgetPhoto.reframe"].tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		checkpoint("store-\(locale)-crop-\(index)-widgetPhoto")
		app.buttons["crop.use"].tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.widgetPhoto.loaded"].waitForExistence(timeout: 10))
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
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
	}

	/// Editor chips are buttons that report their state as a "1"/"0" value.
	private func chip(_ identifier: String) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	/// With `croppedTo`, keeps the centered part of the element at that point size (the widget preview is centered).
	private func checkpoint(_ name: String, element: XCUIElement? = nil, croppedTo size: CGSize? = nil) {
		let screenshot = element?.screenshot() ?? app.screenshot()
		let attachment: XCTAttachment
		if let element, let size, let cgImage = screenshot.image.cgImage {
			let scale = CGFloat(cgImage.width) / element.frame.width
			let crop = CGRect(
				x: (element.frame.width - size.width) / 2 * scale, y: (element.frame.height - size.height) / 2 * scale,
				width: size.width * scale, height: size.height * scale
			).integral
			attachment = XCTAttachment(image: UIImage(cgImage: cgImage.cropping(to: crop) ?? cgImage), quality: .original)
		} else {
			attachment = XCTAttachment(screenshot: screenshot)
		}
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
