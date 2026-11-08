import CoreHaptics
import XCTest

@testable import GrowingUp

/// Making a Core Haptics engine waits on the haptic server over XPC. On the main thread a slow server froze the app
/// until the watchdog ended it, so a celebration must never make the engine there.
@MainActor
final class BirthdayHapticEngineTests: XCTestCase {
	private static let pulses = BirthdayHapticPattern.pulses(for: .poppers)

	func testTheEngineIsMadeOffTheMainThreadAndOnlyOnce() {
		let made = expectation(description: "the engine is made once")
		let release = DispatchSemaphore(value: 0)
		let haptics = BirthdayHapticEngine(makeEngine: {
			XCTAssertFalse(Thread.isMainThread, "Making the engine must not block the main thread")
			// A main-thread call would wait here instead of returning to the test.
			XCTAssertEqual(release.wait(timeout: .now() + 2), .success)
			made.fulfill()
			return nil
		})

		haptics.play(Self.pulses, startedAt: Date())
		haptics.play(Self.pulses, startedAt: Date())
		release.signal()

		wait(for: [made], timeout: 5)
	}

	func testACelebrationAfterAnUnavailableEngineAsksAgain() {
		let queue = DispatchQueue(label: "BirthdayHapticEngineTests")
		let asked = DispatchSemaphore(value: 0)
		let haptics = BirthdayHapticEngine(
			makeEngine: {
				asked.signal()
				return nil
			}, engineQueue: queue)

		haptics.play(Self.pulses, startedAt: Date())
		XCTAssertEqual(asked.wait(timeout: .now() + 5), .success, "The first celebration asks for an engine")
		waitForTheMadeEngine(on: queue)
		haptics.play(Self.pulses, startedAt: Date())

		XCTAssertEqual(asked.wait(timeout: .now() + 5), .success, "Without an engine the next celebration asks again")
	}

	/// The serial engine queue hands its result to the main queue before it runs anything after it.
	private func waitForTheMadeEngine(on queue: DispatchQueue) {
		let delivered = expectation(description: "the made engine reached the main thread")
		queue.async {
			DispatchQueue.main.async { delivered.fulfill() }
		}
		wait(for: [delivered], timeout: 5)
	}
}
