import WidgetKit
import XCTest

@testable import GrowingUp

final class WidgetTileLayoutTests: XCTestCase {
	func testLargeWidgetFillsEveryRowForOneToSixPeople() {
		let expected: [Int: [Range<Int>]] = [
			1: [0..<1],
			2: [0..<1, 1..<2],
			3: [0..<1, 1..<3],
			4: [0..<2, 2..<4],
			5: [0..<2, 2..<5],
			6: [0..<3, 3..<6]
		]
		for (count, rows) in expected {
			XCTAssertEqual(WidgetTileLayout.rows(count: count, family: .systemLarge), rows, "\(count) people")
		}
	}

	func testMediumWidgetShowsUpToThreePeopleInOneRow() {
		XCTAssertEqual(WidgetTileLayout.rows(count: 1, family: .systemMedium), [0..<1])
		XCTAssertEqual(WidgetTileLayout.rows(count: 2, family: .systemMedium), [0..<2])
		XCTAssertEqual(WidgetTileLayout.rows(count: 6, family: .systemMedium), [0..<3])
	}

	func testSmallWidgetShowsTheFirstPersonOnly() {
		XCTAssertEqual(WidgetTileLayout.rows(count: 4, family: .systemSmall), [0..<1])
	}

	func testNobodyPinnedHasNoRows() {
		for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
			XCTAssertEqual(WidgetTileLayout.rows(count: 0, family: family), [])
		}
	}

	/// Rows cover the shown people exactly once and in pinned order, so every tile keeps its deep link.
	func testRowsCoverThePeopleInOrderWithoutGaps() {
		for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
			for count in 0...8 {
				let indices = WidgetTileLayout.rows(count: count, family: family).flatMap { Array($0) }
				XCTAssertEqual(indices, Array(0..<min(count, WidgetTileLayout.capacity(of: family))), "\(family) \(count)")
			}
		}
	}
}
