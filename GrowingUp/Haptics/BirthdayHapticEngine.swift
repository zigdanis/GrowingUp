import CoreHaptics
import OSLog

/// Plays the birthday pattern through Core Haptics, which ramps a rumble and places taps to the hundredth of a second,
/// as UIKit's feedback generators cannot. Devices without haptics, such as iPads, stay silent.
///
/// The engine starts asynchronously and the pattern is timed from when the confetti started, so the visuals never wait
/// for it: what is already past by the time the engine runs is skipped, never played late. Any Core Haptics failure only
/// skips that celebration.
@MainActor
final class BirthdayHapticEngine {
	private static let logger = Logger(subsystem: "pro.ziganshin.GrowingUp", category: "Haptics")

	private lazy var supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
	private var engine: CHHapticEngine?
	private var players: [any CHHapticPatternPlayer] = []
	/// Counts celebrations, so an engine that finishes starting after a newer one began, or after a stop, plays nothing.
	private var generation = 0

	/// Plays `pulses`, timed from `start`, in place of any celebration still playing.
	func play(_ pulses: [HapticPulse], startedAt start: Date) {
		stopPlayers()
		generation += 1
		guard supportsHaptics, let engine = makeEngine() else { return }
		let celebration = generation
		engine.start { [weak self] error in
			let failure = error?.localizedDescription
			Task { @MainActor in
				guard let self, celebration == self.generation else { return }
				if let failure {
					Self.logger.error("haptic engine did not start: \(failure, privacy: .public)")
					return
				}
				self.schedule(pulses, startedAt: start)
			}
		}
	}

	/// Ends the celebration at once and lets the engine rest.
	func stop() {
		generation += 1
		guard let engine else { return }
		stopPlayers()
		engine.stop(completionHandler: nil)
	}

	private func makeEngine() -> CHHapticEngine? {
		if let engine { return engine }
		do {
			let created = try CHHapticEngine()
			created.playsHapticsOnly = true
			created.isAutoShutdownEnabled = true
			// The system reset the haptic server: the players are gone, so the celebration ends there and the engine restarts.
			created.resetHandler = { [weak self] in
				Task { @MainActor in self?.engineDidReset() }
			}
			created.stoppedHandler = { [weak self] _ in
				Task { @MainActor in self?.players.removeAll() }
			}
			engine = created
			return created
		} catch {
			Self.logger.error("haptic engine unavailable: \(error.localizedDescription, privacy: .public)")
			return nil
		}
	}

	private func engineDidReset() {
		players.removeAll()
		generation += 1
		engine?.start(completionHandler: nil)
	}

	/// Starts what is left of `pulses` now that the engine runs: the taps as one pattern, and every rumble as its own,
	/// because an intensity curve dims every event of its pattern and must not soften a tap or another rumble.
	private func schedule(_ pulses: [HapticPulse], startedAt start: Date) {
		guard let engine else { return }
		let elapsed = max(Date().timeIntervalSince(start), 0)
		let remaining = pulses.compactMap { $0.remainder(after: elapsed) }
		let taps = remaining.filter(\.isTransient).map(Self.tapEvent)
		var patterns = remaining.filter { !$0.isTransient }.map(Self.rumblePattern)
		if !taps.isEmpty { patterns.append(try? CHHapticPattern(events: taps, parameters: [])) }
		do {
			for case let pattern? in patterns {
				let player = try engine.makePlayer(with: pattern)
				try player.start(atTime: CHHapticTimeImmediate)
				players.append(player)
			}
		} catch {
			Self.logger.error("haptic pattern did not play: \(error.localizedDescription, privacy: .public)")
			stopPlayers()
		}
	}

	private func stopPlayers() {
		for player in players {
			try? player.stop(atTime: CHHapticTimeImmediate)
		}
		players.removeAll()
	}

	private nonisolated static func tapEvent(_ pulse: HapticPulse) -> CHHapticEvent {
		CHHapticEvent(
			eventType: .hapticTransient, parameters: parameters(intensity: pulse.peakIntensity, sharpness: pulse.sharpness),
			relativeTime: pulse.time)
	}

	/// A rumble at its peak intensity, with a curve that ramps it from the start's share of the peak to the end's.
	private nonisolated static func rumblePattern(_ pulse: HapticPulse) -> CHHapticPattern? {
		let peak = pulse.peakIntensity
		guard peak > 0 else { return nil }
		let event = CHHapticEvent(
			eventType: .hapticContinuous, parameters: parameters(intensity: peak, sharpness: pulse.sharpness), relativeTime: pulse.time,
			duration: pulse.duration)
		var curves: [CHHapticParameterCurve] = []
		if pulse.startIntensity != pulse.endIntensity {
			let points = [
				CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: Float(pulse.startIntensity / peak)),
				CHHapticParameterCurve.ControlPoint(relativeTime: pulse.duration, value: Float(pulse.endIntensity / peak))
			]
			curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points, relativeTime: pulse.time))
		}
		return try? CHHapticPattern(events: [event], parameterCurves: curves)
	}

	private nonisolated static func parameters(intensity: Double, sharpness: Double) -> [CHHapticEventParameter] {
		[
			CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
			CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness))
		]
	}
}
