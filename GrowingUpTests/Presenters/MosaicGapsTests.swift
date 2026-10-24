import SwiftUI
import XCTest

@testable import GrowingUp

final class MosaicGapsTests: XCTestCase {
	func testTheGapsHoldTheMarginsAndSpacingButNotTheTiles() {
		let grid = MosaicGridLayout(size: CGSize(width: 393, height: 852), count: 5)
		let gaps = MosaicGaps(grid: grid, count: 5)
		let path = gaps.path(in: CGRect(x: 0, y: 0, width: 393, height: 1200))
		let first = grid.origin(ofSlot: 0, width: 393)
		let second = grid.origin(ofSlot: 1, width: 393)
		XCTAssertTrue(path.contains(CGPoint(x: 6, y: first.y + 100), eoFill: true), "The leading margin")
		XCTAssertTrue(path.contains(CGPoint(x: (first.x + grid.tileWidth + second.x) / 2, y: first.y + 100), eoFill: true), "The gap")
		XCTAssertTrue(path.contains(CGPoint(x: 200, y: 6), eoFill: true), "The top margin")
		XCTAssertTrue(path.contains(CGPoint(x: 200, y: 1150), eoFill: true), "Below the last row")
		XCTAssertFalse(path.contains(CGPoint(x: first.x + 10, y: first.y + 10), eoFill: true), "Inside a tile")
		XCTAssertFalse(path.contains(CGPoint(x: second.x + grid.tileWidth / 2, y: second.y + grid.tileHeight / 2), eoFill: true))
		XCTAssertTrue(path.contains(CGPoint(x: first.x + 1, y: first.y + 1), eoFill: true), "A tile's rounded corner is a gap")
		let sixth = grid.origin(ofSlot: 5, width: 393)
		XCTAssertTrue(path.contains(CGPoint(x: sixth.x + 50, y: sixth.y + 50), eoFill: true), "An empty slot is a gap")
	}
}
