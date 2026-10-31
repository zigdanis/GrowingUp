import XCTest

@testable import GrowingUp

final class BirthdayHapticPatternTests: XCTestCase {
	func testEveryPatternPlaysInOrderWithinTheCelebration() {
		for style in ConfettiStyle.allCases {
			let pulses = BirthdayHapticPattern.pulses(for: style)
			XCTAssertFalse(pulses.isEmpty, "\(style)")
			XCTAssertEqual(pulses.map(\.time), pulses.map(\.time).sorted(), "\(style)")
			for pulse in pulses {
				XCTAssertGreaterThanOrEqual(pulse.time, 0, "\(style)")
				XCTAssertGreaterThanOrEqual(pulse.duration, 0, "\(style)")
				XCTAssertLessThanOrEqual(pulse.time + pulse.duration, ConfettiStyle.duration, "\(style)")
				for value in [pulse.startIntensity, pulse.endIntensity, pulse.sharpness] {
					XCTAssertTrue((0...1).contains(value), "\(style) \(pulse)")
				}
				if pulse.isTransient {
					XCTAssertEqual(pulse.startIntensity, pulse.endIntensity, "\(style) \(pulse)")
				}
			}
		}
	}

	func testFireworksBurstOnTheShellsBeats() {
		let bursts = BirthdayHapticPattern.pulses(for: .fireworks).filter(\.isTransient)
		XCTAssertEqual(bursts.map(\.time), ConfettiStyle.fireworkBursts)
	}

	func testPoppersOpenWithTheirStrongestPop() throws {
		let pulses = BirthdayHapticPattern.pulses(for: .poppers)
		let first = try XCTUnwrap(pulses.first)
		XCTAssertEqual(first.time, 0)
		XCTAssertTrue(first.isTransient)
		for pulse in pulses.dropFirst() {
			XCTAssertLessThan(pulse.peakIntensity, first.peakIntensity)
		}
	}

	func testAPatternJoinedLateSkipsWhatIsPastAndKeepsTheRestInStep() throws {
		let tap = HapticPulse.tap(at: 0.2, intensity: 0.8, sharpness: 0.5)
		XCTAssertEqual(tap.remainder(after: 0), .tap(at: 0.2, intensity: 0.8, sharpness: 0.5))
		XCTAssertEqual(tap.remainder(after: 0.22), .tap(at: 0, intensity: 0.8, sharpness: 0.5), "A barely late tap plays at once")
		XCTAssertNil(tap.remainder(after: 0.3), "A tap long past never plays late")
		let ramp = HapticPulse.ramp(at: 1, duration: 1, from: 0.4, to: 0, sharpness: 0.2)
		let rest = try XCTUnwrap(ramp.remainder(after: 1.5))
		XCTAssertEqual(rest.time, 0)
		XCTAssertEqual(rest.duration, 0.5, accuracy: 1e-9)
		XCTAssertEqual(rest.startIntensity, 0.2, accuracy: 1e-9)
		XCTAssertEqual(rest.endIntensity, 0)
		XCTAssertNil(ramp.remainder(after: 2))
		XCTAssertEqual(ramp.remainder(after: 0.25)?.time, 0.75)
	}
}
