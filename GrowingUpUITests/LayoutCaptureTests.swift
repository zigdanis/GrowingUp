import XCTest

/// Opt-in captures of the app's screens on the demo people, written as PNGs for a layout review on each device size.
///
/// `GROWINGUP_LAYOUT_CAPTURE` names the directory for the PNGs and their `captures.json`; `GROWINGUP_LAYOUT_DEVICE` the
/// device in their names; `GROWINGUP_LAYOUT_ORIENTATIONS` the orientations, such as `portrait,landscape`; and
/// `GROWINGUP_LAYOUT_SCREENS` an optional subset of the screens. Pass them with xcodebuild's `TEST_RUNNER_` prefix.
@MainActor
final class LayoutCaptureTests: XCTestCase {
	private let app = XCUIApplication()
	private var directory: URL!
	private var device = ""
	private var orientation = ""
	private var screens: Set<String>?
	private var photos = ""
	private var captures: [[String: Any]] = []
	private var overview: XCUIElement { app.buttons["person.name"] }
	private var save: XCUIElement { app.buttons["editor.save"] }

	func testCaptureLayouts() throws {
		let environment = ProcessInfo.processInfo.environment
		guard let path = environment["GROWINGUP_LAYOUT_CAPTURE"] else { throw XCTSkip("Opt-in layout capture") }
		directory = URL(fileURLWithPath: path)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		device = environment["GROWINGUP_LAYOUT_DEVICE"] ?? "device"
		photos = try XCTUnwrap(environment["GROWINGUP_APP_STORE_PHOTOS"])
		screens = environment["GROWINGUP_LAYOUT_SCREENS"].flatMap { $0.isEmpty ? nil : Set($0.split(separator: ",").map(String.init)) }
		continueAfterFailure = false
		for name in (environment["GROWINGUP_LAYOUT_ORIENTATIONS"] ?? "portrait").split(separator: ",").map(String.init) {
			orientation = name
			XCUIDevice.shared.orientation = name == "landscape" ? .landscapeLeft : .portrait
			captureDemoPeople()
			if wants("mosaic-one") {
				launch(seed: .demoMia)
				capture("mosaic-one", note: "Mia alone")
			}
			if wants("empty") {
				launch(seed: .empty)
				capture("empty", note: "The invitation and Add person")
			}
			for family in ["small", "medium", "large", "extraLarge"] where wants("widget-\(family)") {
				launch(seed: .demo, widgetFamily: family)
				XCTAssertTrue(app.otherElements["widget.preview"].waitForExistence(timeout: 10))
				Thread.sleep(forTimeInterval: 1)
				capture("widget-\(family)", note: "UITestWidgetPreview, \(family)")
			}
		}
		XCUIDevice.shared.orientation = .portrait
		let index = directory.appendingPathComponent("captures-\(device).json")
		try JSONSerialization.data(withJSONObject: captures, options: [.prettyPrinted, .sortedKeys]).write(to: index)
	}

	// MARK: - Screens

	private func captureDemoPeople() {
		launch(seed: .demo)
		if wants("mosaic") {
			// Tile pictures load asynchronously and expose no loaded marker.
			Thread.sleep(forTimeInterval: 1.5)
			capture("mosaic", note: "Four demo people")
		}
		let editing = ["edit", "date", "time", "remove", "photos", "crop", "circle", "camera"]
		guard wants("viewer") || wants("birthday") || editing.contains(where: wants) else { return }
		open(person: 0, named: "Mia")
		Thread.sleep(forTimeInterval: 1)
		if wants("viewer") { capture("viewer", note: "Mia") }
		if wants("birthday") { captureBirthday() }
		if editing.contains(where: wants) { captureEditMode() }
	}

	private func captureBirthday() {
		app.swipeLeft()
		XCTAssertTrue(wait(for: overview, label: "Leo"))
		// The confetti's first second, while it fills the page.
		Thread.sleep(forTimeInterval: 0.8)
		capture("viewer-birthday", note: "Leo's birthday with confetti")
		app.swipeRight()
		XCTAssertTrue(wait(for: overview, label: "Mia"))
	}

	private func captureEditMode() {
		overview.tap()
		XCTAssertTrue(save.waitForExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 10))
		Thread.sleep(forTimeInterval: 0.5)
		if wants("edit") { capture("edit", note: "Mia's edit mode") }
		if wants("date") { capturePopover(capsule: "editor.birthDate", picker: "editor.birthDate.picker", screen: "edit-date") }
		if wants("time") { capturePopover(capsule: "editor.birthTime", picker: "editor.birthTime.picker", screen: "edit-time") }
		if wants("remove") { captureRemoval() }
		if wants("circle") { captureCircle() }
		if wants("camera") { captureCamera() }
		if wants("photos") || wants("crop") { capturePhotosAndCrop() }
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(save.waitForNonExistence(timeout: 5))
	}

	private func capturePopover(capsule: String, picker: String, screen: String) {
		app.buttons[capsule].tap()
		XCTAssertTrue(app.datePickers[picker].waitForExistence(timeout: 5))
		Thread.sleep(forTimeInterval: 0.6)
		capture(screen, note: screen == "edit-date" ? "Day of birth" : "Time of birth")
		dismissOverlay()
		XCTAssertTrue(app.datePickers[picker].waitForNonExistence(timeout: 5))
	}

	private func captureRemoval() {
		app.buttons["editor.remove"].tap()
		Thread.sleep(forTimeInterval: 0.8)
		capture("edit-remove", note: "Remove confirmation")
		if app.alerts.firstMatch.exists {
			app.alerts.firstMatch.buttons["Cancel"].tap()
		} else {
			dismissOverlay()
		}
		Thread.sleep(forTimeInterval: 0.6)
		XCTAssertTrue(save.isHittable)
	}

	private func captureCircle() {
		app.buttons["editor.widgetPhoto.reframe"].tap()
		XCTAssertTrue(app.buttons["crop.cancel"].waitForExistence(timeout: 5))
		Thread.sleep(forTimeInterval: 0.6)
		capture("crop-circle", note: "Widget picture's circle")
		app.buttons["crop.cancel"].tap()
		XCTAssertTrue(app.buttons["crop.cancel"].waitForNonExistence(timeout: 5))
	}

	private func captureCamera() {
		app.buttons["editor.appPhoto"].tap()
		app.buttons["photo.source.camera"].tap()
		XCTAssertTrue(app.buttons["camera.back"].waitForExistence(timeout: 5))
		Thread.sleep(forTimeInterval: 1)
		capture("camera", note: "Camera sheet")
		app.buttons["camera.back"].tap()
		XCTAssertTrue(app.buttons["camera.back"].waitForNonExistence(timeout: 5))
	}

	private func capturePhotosAndCrop() {
		app.buttons["editor.appPhoto"].tap()
		app.buttons["photo.source.photos"].tap()
		let thumbnails = app.buttons.matching(identifier: "photo.thumbnail")
		XCTAssertTrue(thumbnails.firstMatch.waitForExistence(timeout: 5))
		Thread.sleep(forTimeInterval: 1)
		if wants("photos") { capture("photos", note: "Photos sheet") }
		thumbnails.element(boundBy: 1).tap()
		XCTAssertTrue(app.buttons["crop.use"].waitForExistence(timeout: 5))
		Thread.sleep(forTimeInterval: 0.6)
		if wants("crop") { capture("crop", note: "Main photo's crop") }
		app.buttons["crop.use"].tap()
		XCTAssertTrue(thumbnails.firstMatch.waitForNonExistence(timeout: 5))
		XCTAssertTrue(app.images["editor.appPhoto.loaded"].waitForExistence(timeout: 10))
	}

	// MARK: - Steps

	private func launch(seed: UITestSeed, widgetFamily: String? = nil) {
		app.terminate()
		let configuration = UITestConfiguration(identifier: UUID(), resetStore: true, seed: seed, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"GROWINGUP_APP_STORE_CAPTURE": "1", "GROWINGUP_APP_STORE_PHOTOS": photos,
			"GROWINGUP_BIRTHDAY_NOW": "2027-01-16T08:24:12Z", "TZ": "UTC"
		]
		app.launchEnvironment["GROWINGUP_WIDGET_PREVIEW"] = widgetFamily
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", "Dark",
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		guard widgetFamily == nil else { return }
		let ready = seed == .empty ? app.buttons["person.add"] : app.buttons.matching(identifier: "people.tile").firstMatch
		XCTAssertTrue(ready.waitForExistence(timeout: 10))
	}

	private func open(person index: Int, named name: String) {
		app.open(URL(string: "growingup-app://?personIndex=\(index)")!)
		XCTAssertTrue(wait(for: overview, label: name))
	}

	/// Closes the open card or popover with a tap on the photo below it, clear of the controls along the bottom.
	private func dismissOverlay() {
		app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
	}

	private func wants(_ screen: String) -> Bool {
		screens?.contains(screen) ?? true
	}

	private func wait(for element: XCUIElement, label: String) -> Bool {
		let predicate = NSPredicate(format: "label == %@", label)
		return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed
	}

	private func capture(_ screen: String, note: String) {
		let name = "\(device)-\(orientation)-\(screen).png"
		do {
			try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(name))
		} catch {
			XCTFail("Could not write \(name): \(error)")
		}
		let window = app.windows.firstMatch.frame.size
		captures.append([
			"file": name, "device": device, "orientation": orientation, "screen": screen, "note": note,
			"window": ["width": window.width, "height": window.height]
		])
	}
}
