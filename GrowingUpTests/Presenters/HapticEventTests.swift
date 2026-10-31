import XCTest

@testable import GrowingUp

final class HapticEventTests: XCTestCase {
	func testEveryEventPlaysAFeedbackWithinTheEnginesRange() {
		for event in HapticEvent.allCases {
			guard case .impact(_, let intensity) = event.feedback else { continue }
			XCTAssertTrue((0...1).contains(intensity), "\(event)")
		}
	}

	func testOnlyASwappedSlotIsThrottled() {
		for event in HapticEvent.allCases where event != .slotSwapped {
			XCTAssertEqual(event.minimumInterval, 0, "\(event)")
		}
		XCTAssertEqual(HapticEvent.slotSwapped.minimumInterval, 0.12)
	}

	func testALiftedTileKeepsTheMosaicsMediumImpact() {
		XCTAssertEqual(HapticEvent.reorderLifted.feedback, .impact(.medium, intensity: 1))
	}

	func testOutcomesUseTheSystemNotifications() {
		XCTAssertEqual(HapticEvent.saved.feedback, .notification(.success))
		XCTAssertEqual(HapticEvent.removalConfirmationShown.feedback, .notification(.warning))
		XCTAssertEqual(HapticEvent.failure.feedback, .notification(.error))
		XCTAssertEqual(HapticEvent.slotSwapped.feedback, .selection)
	}
}
