import XCTest

@testable import GrowingUp

final class HapticThrottleTests: XCTestCase {
	private let start = Date(timeIntervalSince1970: 1_800_000_000)

	func testASecondSwapInsideTheIntervalIsDropped() {
		var throttle = HapticThrottle()
		XCTAssertTrue(throttle.allows(.slotSwapped, at: start))
		XCTAssertFalse(throttle.allows(.slotSwapped, at: start.addingTimeInterval(0.05)))
		XCTAssertFalse(throttle.allows(.slotSwapped, at: start.addingTimeInterval(0.11)))
	}

	func testASwapAfterTheIntervalPlays() {
		var throttle = HapticThrottle()
		XCTAssertTrue(throttle.allows(.slotSwapped, at: start))
		XCTAssertTrue(throttle.allows(.slotSwapped, at: start.addingTimeInterval(0.12)))
		XCTAssertFalse(throttle.allows(.slotSwapped, at: start.addingTimeInterval(0.2)), "The interval runs from the last play")
	}

	func testEventsAreThrottledApart() {
		var throttle = HapticThrottle()
		XCTAssertTrue(throttle.allows(.slotSwapped, at: start))
		XCTAssertTrue(throttle.allows(.dropped, at: start.addingTimeInterval(0.01)))
		XCTAssertFalse(throttle.allows(.slotSwapped, at: start.addingTimeInterval(0.02)))
	}

	func testEventsWithoutAnIntervalAlwaysPlay() {
		var throttle = HapticThrottle()
		for event in HapticEvent.allCases where event.minimumInterval == 0 {
			XCTAssertTrue(throttle.allows(event, at: start), "\(event)")
			XCTAssertTrue(throttle.allows(event, at: start), "\(event)")
		}
	}
}
