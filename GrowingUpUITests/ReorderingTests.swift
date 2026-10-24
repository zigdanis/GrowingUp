import XCTest

@MainActor
final class ReorderingTests: XCTestCase {
	private var app: XCUIApplication!
	private var configuration: UITestConfiguration!
	private var tiles: XCUIElementQuery { app.buttons.matching(identifier: "people.tile") }
	private var done: XCUIElement { app.buttons["people.reorder.done"] }
	private var add: XCUIElement { app.buttons["person.add"] }

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
		configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: .sixPinned, failNextSave: false, appearance: .dark)
	}

	func testLongPressDragsATileAndTheOrderSurvivesARelaunch() {
		launch()
		XCTAssertEqual(mosaicOrder(), ["Alice", "Boris", "Clara", "Daria", "Evan", "Farah"])
		XCTAssertFalse(done.exists)
		// One press lifts Alice and, without letting go, carries her onto Daria's place.
		tile("Alice").press(forDuration: 1, thenDragTo: tile("Daria"))
		XCTAssertTrue(done.waitForExistence(timeout: 5), "A long press starts reordering")
		XCTAssertFalse(add.exists, "Done takes the Add button's place")
		XCTAssertEqual(mosaicOrder(), ["Boris", "Clara", "Daria", "Alice", "Evan", "Farah"])
		checkpoint("mosaic-reordering")
		// While reordering, a tap on a tile opens nobody.
		tile("Boris").tap()
		XCTAssertFalse(app.buttons["person.name"].waitForExistence(timeout: 1))
		done.tap()
		XCTAssertTrue(add.waitForExistence(timeout: 5))
		XCTAssertFalse(done.exists)

		relaunch()
		XCTAssertEqual(mosaicOrder(), ["Boris", "Clara", "Daria", "Alice", "Evan", "Farah"])
		// The viewer pages through people in the new order.
		tile("Daria").tap()
		let name = app.buttons["person.name"]
		XCTAssertTrue(waitFor(name, label: "Daria"))
		app.swipeLeft()
		XCTAssertTrue(waitFor(name, label: "Alice"))
		app.terminate()

		// The widgets show the pinned people in the mosaic's order too.
		relaunch(widgetFamily: "medium")
		let names = ["Boris", "Clara", "Daria"]
		let widgetTiles = names.map { name in
			app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
		}
		for tile in widgetTiles { XCTAssertTrue(tile.waitForExistence(timeout: 5)) }
		XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Alice'")).firstMatch.exists)
		XCTAssertLessThan(widgetTiles[0].frame.minX, widgetTiles[1].frame.minX)
		XCTAssertLessThan(widgetTiles[1].frame.minX, widgetTiles[2].frame.minX)
	}

	func testHoldingATileAtTheBottomEdgeScrollsItToTheEnd() {
		launch()
		let bottomEdge = add.frame.minY - 24
		let boris = tile("Boris")
		let start = boris.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
		let edge = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: boris.frame.midX, dy: bottomEdge))
		start.press(forDuration: 1, thenDragTo: edge, withVelocity: .default, thenHoldForDuration: 3)
		XCTAssertTrue(done.waitForExistence(timeout: 5))
		XCTAssertTrue(tile("Farah").isHittable, "The mosaic scrolled down to its last row")
		XCTAssertEqual(mosaicOrder(), ["Alice", "Clara", "Daria", "Evan", "Farah", "Boris"])
		done.tap()
		relaunch()
		XCTAssertEqual(mosaicOrder(), ["Alice", "Clara", "Daria", "Evan", "Farah", "Boris"])
	}

	private func launch() {
		app.launchEnvironment = [UITestConfiguration.environmentKey: configuration.encoded, "TZ": "UTC"]
		app.launchArguments = [
			"-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", configuration.appearance.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
	}

	private func relaunch(widgetFamily: String? = nil) {
		app.terminate()
		configuration = configuration.forRelaunch()
		app.launchEnvironment[UITestConfiguration.environmentKey] = configuration.encoded
		app.launchEnvironment["GROWINGUP_WIDGET_PREVIEW"] = widgetFamily
		app.launch()
		if widgetFamily == nil {
			XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
		} else {
			XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "widget.preview").firstMatch.waitForExistence(timeout: 10))
		}
	}

	/// The tiles' names in reading order: row by row, leading to trailing.
	private func mosaicOrder() -> [String] {
		let tiles = tiles.allElementsBoundByIndex.map { ($0.frame, $0.label) }
		return
			tiles
			.sorted { lhs, rhs in
				abs(lhs.0.midY - rhs.0.midY) > lhs.0.height / 2 ? lhs.0.midY < rhs.0.midY : lhs.0.midX < rhs.0.midX
			}
			.map { String($0.1.prefix { $0 != "," }) }
	}

	private func tile(_ name: String) -> XCUIElement {
		tiles.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
	}

	private func waitFor(_ element: XCUIElement, label: String) -> Bool {
		let predicate = NSPredicate(format: "label == %@", label)
		return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed
	}

	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
