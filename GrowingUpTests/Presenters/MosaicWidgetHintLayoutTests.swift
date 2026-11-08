import XCTest

@testable import GrowingUp

/// Where the widget hint sits in the mosaic: a card in the free slot of the last row, or a row of its own.
final class MosaicWidgetHintLayoutTests: XCTestCase {
	private let phone = CGSize(width: 393, height: 700)

	func testOnePersonOnAnIPhoneStandsBesideTheCard() {
		let placed = MosaicGridLayout.withWidgetHint(size: phone, count: 1)
		XCTAssertEqual(placed.hint, .slot(1))
		XCTAssertEqual(placed.grid.columns, 2)
		XCTAssertEqual(placed.grid.tileWidth, MosaicGridLayout(size: phone, count: 1).tileWidth, accuracy: 0.01)
	}

	func testAnOddNumberOfPeopleOnAnIPhoneFillsTheLastRowWithTheCard() {
		XCTAssertEqual(MosaicGridLayout.withWidgetHint(size: phone, count: 3).hint, .slot(3))
		XCTAssertEqual(MosaicGridLayout.withWidgetHint(size: phone, count: 5).hint, .slot(5))
		XCTAssertEqual(MosaicGridLayout.withWidgetHint(size: phone, count: 3).grid, MosaicGridLayout(size: phone, count: 3))
	}

	func testAFullLastRowGetsTheHintAsARowAndKeepsTheTilesWhereTheyAre() {
		for count in [2, 4, 20] {
			let placed = MosaicGridLayout.withWidgetHint(size: phone, count: count)
			XCTAssertEqual(placed.hint, .row, "\(count) people")
			XCTAssertEqual(placed.grid, MosaicGridLayout(size: phone, count: count), "\(count) people")
		}
		XCTAssertEqual(MosaicGridLayout(size: phone, count: 2).contentWidth, 369, accuracy: 0.01)
	}

	func testAnIPadThatFitsItsPeopleToTheWindowCountsTheCardAsATile() {
		let pad = CGSize(width: 820, height: 1080)
		let three = MosaicGridLayout.withWidgetHint(size: pad, count: 3, minimumTileWidth: 200, maximumTileWidth: 400, fillsWindow: true)
		XCTAssertEqual(three.hint, .slot(3))
		XCTAssertEqual(three.grid, MosaicGridLayout(size: pad, count: 4, minimumTileWidth: 200, maximumTileWidth: 400, fillsWindow: true))
		let two = MosaicGridLayout.withWidgetHint(size: pad, count: 2, minimumTileWidth: 200, maximumTileWidth: 400, fillsWindow: true)
		XCTAssertEqual(two.hint, .row)
		XCTAssertEqual(two.grid, MosaicGridLayout(size: pad, count: 2, minimumTileWidth: 200, maximumTileWidth: 400, fillsWindow: true))
	}

	func testALandscapeIPhoneDuoKeepsTheCardOffTheFold() {
		let duo = CGSize(width: 951, height: 600)
		let placed = MosaicGridLayout.withWidgetHint(size: duo, count: 1, evenColumns: true)
		XCTAssertEqual(placed.grid.columns % 2, 0)
		XCTAssertEqual(placed.hint, .slot(1))
	}
}
