import CoreHaptics
import OSLog

/// Plays the birthday pattern through Core Haptics, which ramps a rumble and places taps to the hundredth of a second,
/// as UIKit's feedback generators cannot. Devices without haptics, such as iPads, stay silent.
///
/// The engine is made off the main thread and starts asynchronously, and the pattern is timed from when the confetti
/// started, so the visuals never wait for it: what is already past by the time the engine runs is skipped, never played
/// late. Any Core Haptics failure only skips that celebration.
@MainActor
final class BirthdayHapticEngine {
	private nonisolated static let logger = Logger(subsystem: "pro.ziganshin.GrowingUp", category: "Haptics")

	/// Making an engine, and asking the hardware whether it has haptics, waits on the haptic server over XPC. On the main
	/// thread a slow server froze the app until the watchdog ended it, so both run on this queue.
	private let engineQueue: DispatchQueue
	private let makeEngine: @Sendable () -> CHHapticEngine?
	private var engine: CHHapticEngine?
	private var isMakingEngine = false
	/// The latest celebration, waiting for the engine. A newer one replaces it and a stop drops it.
	private var waiting: (pulses: [HapticPulse], start: Date)?
	private var players: [any CHHapticPatternPlayer] = []
	/// Counts celebrations, so an engine that finishes starting after a newer one began, or after a stop, plays nothing.
	private var generation = 0

	init(
		makeEngine: @escaping @Sendable () -> CHHapticEngine? = BirthdayHapticEngine.makeDeviceEngine,
		engineQueue: DispatchQueue = DispatchQueue(label: "pro.ziganshin.GrowingUp.haptics", qos: .userInitiated)
	) {
		self.makeEngine = makeEngine
		self.engineQueue = engineQueue
	}

	/// Plays `pulses`, timed from `start`, in place of any celebration still playing.
	func play(_ pulses: [HapticPulse], startedAt start: Date) {
		stopPlayers()
		generation += 1
		if let engine {
			run(engine, playing: pulses, startedAt: start)
		} else {
			waiting = (pulses, start)
			requestEngine()
		}
	}

	/// Ends the celebration at once and lets the engine rest.
	func stop() {
		generation += 1
		waiting = nil
		guard let engine else { return }
		stopPlayers()
		engine.stop(completionHandler: nil)
	}

	/// Makes the engine on `engineQueue`; only one is ever being made, however many celebrations ask meanwhile.
	private func requestEngine() {
		guard !isMakingEngine else { return }
		isMakingEngine = true
		let makeEngine = makeEngine
		engineQueue.async { [weak self] in
			let made = makeEngine()
			DispatchQueue.main.async {
				MainActor.assumeIsolated { self?.engineMade(made) }
			}
		}
	}

	/// Keeps the engine for later celebrations and plays the one still waiting for it. Without an engine that celebration
	/// stays silent, and the next one asks again.
	private func engineMade(_ made: CHHapticEngine?) {
		isMakingEngine = false
		let waiting = waiting
		self.waiting = nil
		guard let made else { return }
		// The system reset the haptic server: the players are gone, so the celebration ends there and the engine restarts.
		made.resetHandler = { [weak self] in
			Task { @MainActor in self?.engineDidReset() }
		}
		made.stoppedHandler = { [weak self] _ in
			Task { @MainActor in self?.players.removeAll() }
		}
		engine = made
		guard let waiting else { return }
		run(made, playing: waiting.pulses, startedAt: waiting.start)
	}

	private func run(_ engine: CHHapticEngine, playing pulses: [HapticPulse], startedAt start: Date) {
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

	/// The device's engine, or nil where there are no haptics or Core Haptics fails. Runs on `engineQueue`.
	nonisolated static func makeDeviceEngine() -> CHHapticEngine? {
		guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
		do {
			let engine = try CHHapticEngine()
			engine.playsHapticsOnly = true
			engine.isAutoShutdownEnabled = true
			return engine
		} catch {
			logger.error("haptic engine unavailable: \(error.localizedDescription, privacy: .public)")
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
			// Every player is made before any starts, then all start at one engine time: starting them one by one would
			// shift each pattern by the time its predecessors took to make, and the taps would drift off the rumbles.
			let ready = try patterns.compactMap { $0 }.map { try engine.makePlayer(with: $0) }
			let startTime = engine.currentTime
			for player in ready {
				try player.start(atTime: startTime)
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
