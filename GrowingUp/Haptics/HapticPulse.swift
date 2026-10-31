import Foundation

/// One beat of a Core Haptics timeline: a tap when it has no duration, otherwise a rumble whose intensity ramps from
/// `startIntensity` to `endIntensity`. Intensity and sharpness run from 0 to 1.
struct HapticPulse: Equatable {
	/// Seconds from the start of the timeline.
	var time: TimeInterval
	/// Seconds the rumble lasts; 0 for a tap.
	var duration: TimeInterval
	var startIntensity: Double
	var endIntensity: Double
	var sharpness: Double

	var isTransient: Bool { duration == 0 }

	/// The strongest intensity the pulse reaches.
	var peakIntensity: Double { max(startIntensity, endIntensity) }

	static func tap(at time: TimeInterval, intensity: Double, sharpness: Double) -> Self {
		Self(time: time, duration: 0, startIntensity: intensity, endIntensity: intensity, sharpness: sharpness)
	}

	static func ramp(at time: TimeInterval, duration: TimeInterval, from start: Double, to end: Double, sharpness: Double) -> Self {
		Self(time: time, duration: duration, startIntensity: start, endIntensity: end, sharpness: sharpness)
	}

	/// What is still to come `elapsed` seconds into the timeline, timed from that moment. A tap up to `tolerance` late
	/// plays at once and an older one is gone; a rumble under way keeps only its rest, from the intensity it has reached.
	func remainder(after elapsed: TimeInterval, tolerance: TimeInterval = 0.05) -> Self? {
		if isTransient {
			guard time + tolerance >= elapsed else { return nil }
			return .tap(at: max(time - elapsed, 0), intensity: startIntensity, sharpness: sharpness)
		}
		let end = time + duration
		guard end > elapsed else { return nil }
		let start = max(time, elapsed)
		let reached = startIntensity + (endIntensity - startIntensity) * (start - time) / duration
		return .ramp(at: start - elapsed, duration: end - start, from: reached, to: endIntensity, sharpness: sharpness)
	}
}
