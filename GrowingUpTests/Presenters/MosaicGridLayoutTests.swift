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
}
