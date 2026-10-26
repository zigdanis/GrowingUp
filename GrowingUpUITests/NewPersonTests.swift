import XCTest

/// "Add" opens a new person's empty edit mode, which Done adds to the end of the mosaic and Cancel drops; a person may
/// have no photo, and removing the last one leaves the invitation.
@MainActor
final class NewPersonTests: XCTestCase {
	private var app: XCUIApplication!
	private var configuration: UITestConfiguration!
	private var overview: XCUIElement { app.buttons["person.name"] }
	private var tiles: XCUIElementQuery { app.buttons.matching(identifier: "people.tile") }
	private var add: XCUIElement { app.buttons["person.add"] }
	private var nameField: XCUIElement { app.textFields["editor.name"] }
	private var done: XCUIElement { app.buttons["editor.save"] }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testAPersonAddedWithoutAPhotoShowsTheirMonogramAfterARelaunch() {
		launch(seed: .empty)
		add.tap()
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The new person is named first")
		XCTAssertEqual(nameField.placeholderValue, "Name")
		XCTAssertTrue(app.buttons["editor.birthDate"].exists)
		XCTAssertTrue(app.buttons["editor.birthTime"].exists)
		XCTAssertFalse(done.isEnabled, "A new person needs a name")
		checkpoint("new-person-edit-mode")
		nameField.typeText("Ada\n")
		XCTAssertTrue(done.isEnabled, "A name is enough; the photo is optional")
		for identifier in ["editor.appPhoto", "editor.pin", "editor.celebrate"] {
			XCTAssertTrue(control(identifier).exists, identifier)
		}
		XCTAssertFalse(app.buttons["editor.remove"].exists, "There is nobody to remove yet")
		XCTAssertFalse(app.buttons["editor.widgetPhoto.reframe"].exists, "Nor a photo to frame a widget picture from")
		XCTAssertEqual(app.buttons["editor.birthDate"].value as? String, "Jan 15, 2027", "Born today by default")
		done.tap()
		XCTAssertTrue(tile("Ada").waitForExistence(timeout: 5), "Done adds a tile to the mosaic")
		XCTAssertTrue(overview.waitForNonExistence(timeout: 5))
		relaunch()
		XCTAssertTrue(tile("Ada").waitForExistence(timeout: 5))
		XCTAssertTrue(waitForMonogram(in: tile("Ada")), "A person without a photo shows their monogram")
		checkpoint("tile-monogram")
		tile("Ada").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		XCTAssertTrue(waitForName("Ada"))
		XCTAssertTrue(waitForMonogram(in: app.windows.firstMatch), "The viewer shows the same monogram")
		checkpoint("viewer-monogram")
	}

	func testANewPersonJoinsTheEndOfTheMosaic() {
		launch(seed: .pinned)
		XCTAssertEqual(tiles.count, 3)
		add.tap()
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		nameField.typeText("Dora\n")
		done.tap()
		XCTAssertTrue(tile("Dora").waitForExistence(timeout: 5))
		XCTAssertEqual(mosaicOrder(), ["Alice", "Boris", "Clara", "Dora"])
	}

	func testCancelAddsNobodyWithoutAQuestion() {
		launch(seed: .pinned)
		XCTAssertEqual(tiles.count, 3)
		add.tap()
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		nameField.typeText("Unsaved")
		app.buttons["editor.cancel"].tap()
		XCTAssertTrue(nameField.waitForNonExistence(timeout: 5), "Cancel closes the new person at once")
		XCTAssertFalse(app.alerts.firstMatch.exists)
		XCTAssertFalse(app.sheets.firstMatch.exists)
		XCTAssertTrue(add.waitForExistence(timeout: 5))
		XCTAssertEqual(tiles.count, 3)
		XCTAssertFalse(tile("Unsaved").exists)
		relaunch()
		XCTAssertEqual(tiles.count, 3)
	}

	func testRemovingTheLastPersonShowsTheInvitation() {
		launch(seed: .onePerson)
		XCTAssertEqual(tiles.count, 1)
		tile("Alice").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		XCTAssertTrue(waitForName("Alice"))
		let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: overview)
		XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
		overview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
		let remove = app.buttons["editor.remove"]
		XCTAssertTrue(remove.waitForExistence(timeout: 5))
		remove.tap()
		let confirmation = app.alerts.buttons["Remove"]
		XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
		confirmation.tap()
		XCTAssertTrue(app.staticTexts["Who is growing up?"].waitForExistence(timeout: 5), "The empty mosaic invites the next person")
		XCTAssertTrue(overview.waitForNonExistence(timeout: 5))
		XCTAssertTrue(add.isHittable)
		XCTAssertEqual(tiles.count, 0)
		checkpoint("last-person-removed")
		relaunch()
		XCTAssertTrue(app.staticTexts["Who is growing up?"].exists)
		XCTAssertEqual(tiles.count, 0)
	}
}

extension NewPersonTests {
	private func launch(seed: UITestSeed) {
		configuration = UITestConfiguration(identifier: UUID(), resetStore: true, seed: seed, failNextSave: false, appearance: .dark)
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", "Dark",
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue((seed == .empty ? add : tiles.firstMatch).waitForExistence(timeout: 10))
	}

	private func relaunch() {
		app.terminate()
		configuration = configuration.forRelaunch()
		app.launchEnvironment[UITestConfiguration.environmentKey] = configuration.encoded
		app.launch()
		XCTAssertTrue(add.waitForExistence(timeout: 10))
	}

	private func tile(_ name: String) -> XCUIElement {
		tiles.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
	}

	/// The tiles' names in reading order: row by row, leading to trailing.
	private func mosaicOrder() -> [String] {
		let tiles: [(frame: CGRect, label: String)] = tiles.allElementsBoundByIndex.map { ($0.frame, $0.label) }
		return
			tiles
			.sorted { lhs, rhs in
				abs(lhs.frame.midY - rhs.frame.midY) > lhs.frame.height / 2 ? lhs.frame.midY < rhs.frame.midY : lhs.frame.midX < rhs.frame.midX
			}
			.map { String($0.label.prefix { $0 != "," }) }
	}

	/// Edit-mode switches are buttons that report their state as a "1"/"0" value.
	private func control(_ identifier: String) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	/// Waits until the middle of `element` shows a monogram's saturated gradient, rather than the grey of a picture that
	/// has not loaded or the black of a missing one. The monogram itself stays out of accessibility, so it is seen, not
	/// queried.
	private func waitForMonogram(in element: XCUIElement) -> Bool {
		let deadline = Date().addingTimeInterval(5)
		repeat {
			if let saturation = middleSaturation(of: element.screenshot().image), saturation > 0.3 { return true }
			Thread.sleep(forTimeInterval: 0.25)
		} while Date() < deadline
		return false
	}

	private func middleSaturation(of image: UIImage) -> CGFloat? {
		guard let pixels = image.cgImage, let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
			let context = CGContext(
				data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: sRGB,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		else { return nil }
		// Shifts the image so its middle pixel covers the 1×1 canvas.
		context.draw(pixels, in: CGRect(x: -pixels.width / 2, y: -pixels.height / 2, width: pixels.width, height: pixels.height))
		guard let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
		var saturation: CGFloat = 0
		UIColor(red: CGFloat(bytes[0]) / 255, green: CGFloat(bytes[1]) / 255, blue: CGFloat(bytes[2]) / 255, alpha: 1)
			.getHue(nil, saturation: &saturation, brightness: nil, alpha: nil)
		return saturation
	}

	private func waitForName(_ name: String) -> Bool {
		let predicate = NSPredicate(format: "label == %@", name)
		return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: overview)], timeout: 5) == .completed
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
