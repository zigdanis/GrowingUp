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
		// While reordering, a tap on a tile opens nobody and keeps reordering.
		tapTile("Boris")
		XCTAssertFalse(app.buttons["person.name"].waitForExistence(timeout: 1))
		XCTAssertTrue(done.exists)
		// A tap on the gap between the tiles finishes reordering, like Done, and opens neither neighbour.
		let gap = CGVector(dx: (tile("Boris").frame.maxX + tile("Clara").frame.minX) / 2, dy: tile("Boris").frame.midY)
		app.coordinate(withNormalizedOffset: .zero).withOffset(gap).tap()
		XCTAssertTrue(add.waitForExistence(timeout: 5))
		XCTAssertFalse(done.exists)
		XCTAssertFalse(app.buttons["person.name"].waitForExistence(timeout: 1))
		// A press that lets go without moving starts reordering too, and letting go opens nobody.
		tile("Boris").press(forDuration: 1)
		XCTAssertTrue(done.waitForExistence(timeout: 5))
		XCTAssertFalse(app.buttons["person.name"].waitForExistence(timeout: 1))
		done.tap()
		XCTAssertTrue(add.waitForExistence(timeout: 5))
		XCTAssertFalse(done.exists)

		relaunch()
		XCTAssertEqual(mosaicOrder(), ["Boris", "Clara", "Daria", "Alice", "Evan", "Farah"])
		// The viewer pages through people in the new order.
		tapTile("Daria")
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

	/// A swipe that starts in the middle of a photo scrolls the mosaic, lifting no tile and opening nobody: at first, while
	/// reordering after a tile was carried to a new place, and once reordering is done.
	func testASwipeStartingOnATileScrollsTheMosaic() {
		launch()
		let viewer = app.buttons["person.name"]
		let top = tile("Alice").frame.minY
		swipe(from: "Clara", by: -320)
		XCTAssertLessThan(tile("Alice").frame.minY, top - 40, "A swipe up from the middle of a tile scrolls the mosaic")
		XCTAssertFalse(done.exists, "It lifts no tile")
		XCTAssertFalse(viewer.exists, "and opens nobody")
		checkpoint("mosaic-scrolled-from-a-tile")
		swipe(from: "Clara", by: 600)
		XCTAssertEqual(tile("Alice").frame.minY, top, accuracy: 2, "A swipe down from a tile scrolls back to the top")

		tile("Alice").press(forDuration: 1, thenDragTo: tile("Boris"))
		XCTAssertTrue(done.waitForExistence(timeout: 5))
		let order = mosaicOrder()
		XCTAssertEqual(order, ["Boris", "Alice", "Clara", "Daria", "Evan", "Farah"])
		let reorderedTop = tile("Boris").frame.minY
		swipe(from: "Daria", by: -320)
		XCTAssertLessThan(tile("Boris").frame.minY, reorderedTop - 40, "A dropped tile leaves the mosaic scrolling")
		XCTAssertEqual(mosaicOrder(), order, "A swipe while reordering moves no tile")
		done.tap()
		XCTAssertTrue(add.waitForExistence(timeout: 5))
		let scrolledTop = tile("Boris").frame.minY
		swipe(from: "Daria", by: 320)
		XCTAssertGreaterThan(tile("Boris").frame.minY, scrolledTop + 40)
		XCTAssertFalse(viewer.exists)
		XCTAssertFalse(done.exists)
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

	/// Taps the centre of `name`'s tile with a real touch: iPhone Duo can keep an empty window over the app that XCTest
	/// takes as covering the tile, so a plain tap would land on its rounded corner.
	private func tapTile(_ name: String) {
		tile(name).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
	}

	/// Swipes vertically by `distance` from the middle of `name`'s tile, starting to move at once as a scroll does, and
	/// holds still at the end so the mosaic stops where the finger left it.
	private func swipe(from name: String, by distance: CGFloat) {
		let start = tile(name).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
		start.press(
			forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)), withVelocity: .default,
			thenHoldForDuration: 0.3)
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
