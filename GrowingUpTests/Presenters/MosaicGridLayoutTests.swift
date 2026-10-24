import XCTest

@testable import GrowingUp

final class MosaicGridLayoutTests: XCTestCase {
	func testAnIPhoneShowsTwoColumnsOfPortraitTiles() {
		let grid = MosaicGridLayout(size: CGSize(width: 393, height: 700), count: 4)
		XCTAssertEqual(grid.columns, 2)
		XCTAssertEqual(grid.tileWidth, 178.5, accuracy: 0.01)
		XCTAssertEqual(grid.tileHeight / grid.tileWidth, 16 / 9, accuracy: 0.001)
	}

	func testOnePersonIsASingleCentredTileOfTheSameSize() {
		let one = MosaicGridLayout(size: CGSize(width: 393, height: 700), count: 1)
		XCTAssertEqual(one.columns, 1)
		XCTAssertEqual(one.tileWidth, MosaicGridLayout(size: CGSize(width: 393, height: 700), count: 4).tileWidth)
	}

	func testWideWindowsAddColumnsInsteadOfGrowingTiles() {
		let grid = MosaicGridLayout(size: CGSize(width: 669, height: 900), count: 20)
		XCTAssertEqual(grid.columns, 3)
		XCTAssertLessThanOrEqual(grid.tileWidth, MosaicGridLayout.maximumTileWidth)
	}

	func testLandscapeKeepsAnEvenColumnCountAndAWholeTileInView() {
		let size = CGSize(width: 951, height: 600)
		let grid = MosaicGridLayout(size: size, count: 20, evenColumns: true)
		XCTAssertEqual(grid.columns % 2, 0)
		XCTAssertLessThanOrEqual(grid.tileHeight, size.height * MosaicGridLayout.maximumHeightShare + 0.01)
		XCTAssertEqual(MosaicGridLayout(size: size, count: 20).columns % 2, 1, "Only the landscape layout asks for even columns")
	}

	func testEveryPortraitPhoneWidthShowsTwoColumns() {
		for (width, tileWidth) in [(320, 142), (375, 169.5), (393, 178.5), (430, 197)] as [(CGFloat, CGFloat)] {
			let grid = MosaicGridLayout(size: CGSize(width: width, height: 700), count: 2)
			XCTAssertEqual(grid.columns, 2, "\(width) pt")
			XCTAssertEqual(grid.tileWidth, tileWidth, accuracy: 0.01, "\(width) pt")
		}
	}

	func testOnePersonInANarrowWindowIsOneCentredTileOfTheTwoColumnWidth() {
		let grid = MosaicGridLayout(size: CGSize(width: 320, height: 700), count: 1)
		XCTAssertEqual(grid.columns, 1)
		XCTAssertEqual(grid.tileWidth, 142, accuracy: 0.01)
	}

	func testLandscapeKeepsEvenColumnsForAnOddNumberOfPeople() {
		let size = CGSize(width: 951, height: 600)
		XCTAssertEqual(MosaicGridLayout(size: size, count: 3, evenColumns: true).columns, 4)
		XCTAssertEqual(MosaicGridLayout(size: size, count: 1, evenColumns: true).columns, 2)
		XCTAssertEqual(MosaicGridLayout(size: size, count: 3).columns, 3)
	}

	func testSlotsSitCentredInRowsBelowTheMargin() {
		let grid = MosaicGridLayout(size: CGSize(width: 393, height: 700), count: 5)
		XCTAssertEqual(grid.origin(ofSlot: 0, width: 393), CGPoint(x: 12, y: 12))
		let third = grid.origin(ofSlot: 3, width: 393)
		XCTAssertEqual(third.x, 12 + grid.tileWidth + 12, accuracy: 0.01)
		XCTAssertEqual(third.y, 12 + grid.tileHeight + 12, accuracy: 0.01)
		let single = MosaicGridLayout(size: CGSize(width: 393, height: 700), count: 1)
		XCTAssertEqual(single.origin(ofSlot: 0, width: 393).x, (393 - single.tileWidth) / 2, accuracy: 0.01)
	}

	func testThePointUnderATileOrNearestToItPicksItsSlot() {
		let grid = MosaicGridLayout(size: CGSize(width: 393, height: 700), count: 5)
		for index in 0..<5 {
			let origin = grid.origin(ofSlot: index, width: 393)
			let centre = CGPoint(x: origin.x + grid.tileWidth / 2, y: origin.y + grid.tileHeight / 2)
			XCTAssertEqual(grid.slot(at: centre, count: 5, width: 393), index)
		}
		XCTAssertEqual(grid.slot(at: CGPoint(x: -40, y: -40), count: 5, width: 393), 0, "Above and before the tiles")
		XCTAssertEqual(grid.slot(at: CGPoint(x: 999, y: 20), count: 5, width: 393), 1, "Beyond the last column")
		XCTAssertEqual(grid.slot(at: CGPoint(x: 380, y: 2000), count: 5, width: 393), 4, "Past the last tile")
	}

	func testTheEmptySlotOfAnOddLandscapeMosaicTakesTheLastTile() {
		let grid = MosaicGridLayout(size: CGSize(width: 951, height: 600), count: 3, evenColumns: true)
		XCTAssertEqual(grid.columns, 4)
		let empty = grid.origin(ofSlot: 3, width: 951)
		let centre = CGPoint(x: empty.x + grid.tileWidth / 2, y: empty.y + grid.tileHeight / 2)
		XCTAssertEqual(grid.slot(at: centre, count: 3, width: 951), 2)
	}
}
