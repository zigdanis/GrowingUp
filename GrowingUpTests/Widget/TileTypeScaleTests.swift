import CoreGraphics
import XCTest

@testable import GrowingUp

final class TileTypeScaleTests: XCTestCase {
	/// Tile sizes of a 6.3-inch iPhone: a 364×382 pt large and a 364×170 pt medium widget with 2 pt seams.
	func testNumbersGrowAsTilesGetBigger() {
		let largeAlone = TileTypeScale(tileSize: CGSize(width: 364, height: 382))
		let mediumAlone = TileTypeScale(tileSize: CGSize(width: 364, height: 170))
		let largeQuarter = TileTypeScale(tileSize: CGSize(width: 181, height: 190))
		let largeSixth = TileTypeScale(tileSize: CGSize(width: 120, height: 190))
		let mediumThird = TileTypeScale(tileSize: CGSize(width: 120, height: 170))
		let narrow = TileTypeScale(tileSize: CGSize(width: 100, height: 190))
		XCTAssertEqual(largeAlone.value, 80)
		XCTAssertEqual(mediumAlone.value, 56)
		XCTAssertEqual(largeQuarter.value, 48)
		XCTAssertEqual(largeSixth, mediumThird)
		XCTAssertEqual(largeSixth.value, 44)
		XCTAssertEqual(narrow.inset, 12)
	}

	func testSmallWidgetUsesTheMediumTier() {
		XCTAssertEqual(TileTypeScale(tileSize: CGSize(width: 170, height: 170)), TileTypeScale(tileSize: CGSize(width: 181, height: 190)))
	}
}
