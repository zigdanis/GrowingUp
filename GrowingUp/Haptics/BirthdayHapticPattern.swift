import Foundation

/// The birthday confetti felt as well as seen: every `ConfettiStyle` gets a Core Haptics timeline in step with what the
/// overlay draws. Pops are sharp taps, falling paper a soft rumble, and each firework shell climbs, bursts and fades.
enum BirthdayHapticPattern {
	/// The pulses of `style`'s celebration in time order, all within `ConfettiStyle.duration`.
	static func pulses(for style: ConfettiStyle) -> [HapticPulse] {
		let pulses: [HapticPulse]
		switch style {
		case .poppers: pulses = poppers
		case .rain: pulses = rain
		case .fireworks: pulses = fireworks
		}
		return pulses.sorted { $0.time < $1.time }
	}

	/// Each popper's two quick pops, as its paper leaves in two waves, then the paper fluttering down.
	private static var poppers: [HapticPulse] {
		[
			.tap(at: 0, intensity: 1, sharpness: 0.9),
			.tap(at: 0.05, intensity: 0.8, sharpness: 0.9),
			.tap(at: 0.18, intensity: 0.6, sharpness: 0.8),
			.tap(at: 0.23, intensity: 0.5, sharpness: 0.8),
			.ramp(at: 0.3, duration: 1, from: 0.25, to: 0, sharpness: 0.1)
		]
	}

	/// A curtain that swells while the paper keeps coming and fades as the last of it falls, with a few light flecks.
	private static var rain: [HapticPulse] {
		let curtain: [HapticPulse] = [
			.ramp(at: 0, duration: 1.1, from: 0.1, to: 0.3, sharpness: 0.15),
			.ramp(at: 1.1, duration: 0.2, from: 0.3, to: 0, sharpness: 0.15)
		]
		return curtain + [0.2, 0.45, 0.7, 0.95].map { HapticPulse.tap(at: $0, intensity: 0.15, sharpness: 0.3) }
	}

	/// Every shell's rocket climbing, its burst, and the afterglow of its sparks; later shells are a little softer.
	private static var fireworks: [HapticPulse] {
		let strengths = [0.9, 0.85, 0.8, 0.75]
		let climb = ConfettiStyle.fireworkClimb
		var pulses: [HapticPulse] = []
		for (burst, strength) in zip(ConfettiStyle.fireworkBursts, strengths) {
			pulses.append(.ramp(at: burst - climb, duration: climb, from: 0.1, to: 0.35, sharpness: 0.6))
			pulses.append(.tap(at: burst, intensity: strength, sharpness: 0.7))
			pulses.append(.ramp(at: burst + 0.05, duration: 0.55, from: 0.3 * strength, to: 0, sharpness: 0.2))
		}
		return pulses
	}
}
