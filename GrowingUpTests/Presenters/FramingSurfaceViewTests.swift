import UIKit
import XCTest

@testable import GrowingUp

/// The edit mode's photo surface keeps every gesture that starts on it while editing: its own move, pinch and double tap
/// begin, and the gestures of the views above it, such as the viewer's pinch to close, do not.
@MainActor
final class FramingSurfaceViewTests: XCTestCase {
	func testOnlyTheSurfacesOwnGesturesBeginOnIt() throws {
		let cover = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
		let surface = FramingSurfaceView(frame: cover.bounds)
		cover.addSubview(surface)
		let closingPinch = UIPinchGestureRecognizer()
		let closingSwipe = UIPanGestureRecognizer()
		cover.addGestureRecognizer(closingPinch)
		cover.addGestureRecognizer(closingSwipe)
		XCTAssertFalse(surface.gestureRecognizerShouldBegin(closingPinch), "The cover's pinch to close waits")
		XCTAssertFalse(surface.gestureRecognizerShouldBegin(closingSwipe), "and so does its swipe")

		let own = try XCTUnwrap(surface.gestureRecognizers)
		XCTAssertEqual(own.count, 3)
		for recognizer in own {
			XCTAssertTrue(surface.gestureRecognizerShouldBegin(recognizer), "\(type(of: recognizer)) frames the photo")
		}
		XCTAssertTrue(own.contains { ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 }, "A double tap puts it back")
		let pan = try XCTUnwrap(own.first { $0 is UIPanGestureRecognizer })
		let pinch = try XCTUnwrap(own.first { $0 is UIPinchGestureRecognizer })
		XCTAssertTrue(surface.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: pinch), "Moving and pinching go together")
		XCTAssertFalse(surface.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: closingPinch))
	}
}
