import SwiftUI
import XCTest

@testable import GrowingUp

final class MosaicAutoscrollTests: XCTestCase {
	/// A portrait phone: the status bar covers the top of the scroll view and the floating button its bottom.
	private let insets = EdgeInsets(top: 60, leading: 0, bottom: 100, trailing: 0)
	private let container = CGSize(width: 393, height: 852)
	/// Three rows of tiles, taller than the phone.
	private let content = CGSize(width: 393, height: 1050)

	func testTheEdgesOfTheVisibleMosaicScrollAndTheMiddleDoesNot() {
		let autoscroll = MosaicAutoscroll(geometry(offset: -60))
		XCTAssertEqual(autoscroll.visible, 0...692)
		XCTAssertEqual(autoscroll.direction(at: CGPoint(x: 100, y: 79)), -1)
		XCTAssertEqual(autoscroll.direction(at: CGPoint(x: 100, y: 80)), 0)
		XCTAssertEqual(autoscroll.direction(at: CGPoint(x: 100, y: 612)), 0)
		XCTAssertEqual(autoscroll.direction(at: CGPoint(x: 100, y: 613)), 1)
	}

	func testScrollingIsFasterTheNearerTheEdgeAndStopsAtTheContentsEnds() throws {
		let autoscroll = MosaicAutoscroll(geometry(offset: -60))
		XCTAssertEqual(autoscroll.positions, 0...358)
		XCTAssertEqual(autoscroll.position, 0)
		XCTAssertNil(autoscroll.position(after: 1, location: CGPoint(x: 100, y: 300)), "Clear of the edges")
		XCTAssertNil(autoscroll.position(after: 1, location: CGPoint(x: 100, y: 10)), "Already at the top")
		// Halfway into the bottom zone scrolls at half speed; at the very edge at full speed.
		XCTAssertEqual(try XCTUnwrap(autoscroll.position(after: 0.1, location: CGPoint(x: 100, y: 652))), 45, accuracy: 0.01)
		XCTAssertEqual(try XCTUnwrap(autoscroll.position(after: 0.1, location: CGPoint(x: 100, y: 692))), 90, accuracy: 0.01)
		// Just inside the zone it still creeps, at 15% of the full speed.
		XCTAssertEqual(try XCTUnwrap(autoscroll.position(after: 0.1, location: CGPoint(x: 100, y: 613))), 13.5, accuracy: 0.01)
		XCTAssertEqual(autoscroll.position(after: 1, location: CGPoint(x: 100, y: 692)), 358, "Never past the last row")

		let scrolledToTheEnd = MosaicAutoscroll(geometry(offset: 298))
		XCTAssertEqual(scrolledToTheEnd.position, 358)
		XCTAssertNil(scrolledToTheEnd.position(after: 1, location: CGPoint(x: 100, y: 1000)), "Already at the bottom")
		XCTAssertEqual(
			try XCTUnwrap(scrolledToTheEnd.position(after: 0.1, location: CGPoint(x: 100, y: 358))), 268, accuracy: 0.01,
			"Back up at full speed from the top edge")
	}

	func testAMosaicThatFitsNeverScrolls() {
		let geometry = ScrollGeometry(
			contentOffset: CGPoint(x: 0, y: -60), contentSize: CGSize(width: 393, height: 400), contentInsets: insets,
			containerSize: container)
		let autoscroll = MosaicAutoscroll(geometry)
		XCTAssertEqual(autoscroll.positions, 0...0)
		XCTAssertNil(autoscroll.position(after: 1, location: CGPoint(x: 100, y: 690)))
	}

	private func geometry(offset: CGFloat) -> ScrollGeometry {
		ScrollGeometry(contentOffset: CGPoint(x: 0, y: offset), contentSize: content, contentInsets: insets, containerSize: container)
	}
}
