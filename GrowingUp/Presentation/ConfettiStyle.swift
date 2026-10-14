import GameplayKit
import SwiftUI

/// Birthday celebrations rotate through these styles so every return to the birthday page feels fresh.
enum ConfettiStyle: CaseIterable {
	/// Two party poppers fire from the bottom corners, then the paper flutters down.
	case poppers
	/// A curtain of confetti falls from the top edge.
	case rain
	/// Rockets climb and burst into glowing shells.
	case fireworks

	/// Every style finishes within this time, so the overlay can be removed afterwards.
	static let duration: TimeInterval = 4

	private static let palette: [Color] = [
		Color(red: 1, green: 0.30, blue: 0.43), Color(red: 1, green: 0.72, blue: 0.01), Color(red: 0.23, green: 0.53, blue: 1),
		Color(red: 0.51, green: 0.22, blue: 0.93), Color(red: 0.02, green: 0.84, blue: 0.63), Color(red: 0.98, green: 0.34, blue: 0.03),
		Color(red: 1, green: 0.56, blue: 0.67)
	]

	/// The first celebration of a page opens with poppers; later ones continue the rotation.
	init(celebration: Int) {
		let styles = Self.allCases
		self = styles[((celebration - 1) % styles.count + styles.count) % styles.count]
	}

	/// The same seed always produces the same particles, so redraws and screenshots stay stable.
	func particles(seed: UInt64) -> [ConfettiParticle] {
		let random = GKMersenneTwisterRandomSource(seed: seed)
		switch self {
		case .poppers: return Self.popperParticles(random)
		case .rain: return Self.rainParticles(random)
		case .fireworks: return Self.fireworkParticles(random)
		}
	}

	private static func popperParticles(_ random: GKRandomSource) -> [ConfettiParticle] {
		(0..<150).map { index -> ConfettiParticle in
			let fromLeft = index.isMultiple(of: 2)
			let angle = value(52...84, random) * .pi / 180
			let speed = value(2.3...3.4, random)
			// Fire in two quick pops: most paper leaves at once, a smaller wave follows.
			let delay = Double(index % 3) * 0.05 + (index >= 100 ? 0.18 : 0)
			let launch = ConfettiParticle(
				shape: .rectangle, color: .clear, delay: delay, lifetime: value(3.2...3.9, random),
				origin: CGPoint(x: fromLeft ? -0.02 : 1.02, y: 1.02),
				velocity: CGVector(dx: (fromLeft ? 1 : -1) * cos(angle) * speed, dy: -sin(angle) * speed),
				drag: value(2.6...3.6, random), gravity: value(0.7...0.95, random))
			return paper(launch, index: index, random: random)
		}
	}

	private static func rainParticles(_ random: GKRandomSource) -> [ConfettiParticle] {
		(0..<170).map { index -> ConfettiParticle in
			let launch = ConfettiParticle(
				shape: .rectangle, color: .clear, delay: value(0...1.1, random), lifetime: value(2.7...2.9, random),
				origin: CGPoint(x: value(0...1, random), y: -0.04),
				velocity: CGVector(dx: value(-0.05...0.05, random), dy: value(0.5...0.8, random)),
				drag: value(2.5...3.5, random), gravity: value(1.1...1.5, random))
			return paper(launch, index: index, random: random)
		}
	}

	private static func fireworkParticles(_ random: GKRandomSource) -> [ConfettiParticle] {
		let shells: [(center: CGPoint, color: Color)] = [
			(CGPoint(x: 0.32, y: 0.30), Color(red: 1, green: 0.72, blue: 0.01)),
			(CGPoint(x: 0.70, y: 0.24), Color(red: 1, green: 0.30, blue: 0.43)),
			(CGPoint(x: 0.50, y: 0.48), Color(red: 0.30, green: 0.79, blue: 0.94)),
			(CGPoint(x: 0.28, y: 0.62), Color(red: 0.78, green: 0.49, blue: 1))
		]
		let climb: TimeInterval = 0.45
		let rocketDrag = 5.0
		return shells.indices.flatMap { index -> [ConfettiParticle] in
			let shell = shells[index]
			let burst = 0.5 + Double(index) * 0.45
			// Drag-only motion covers velocity / drag * decay, so solve for the launch speed that stops at the shell.
			let decay = 1 - exp(-rocketDrag * climb)
			let rocket = ConfettiParticle(
				shape: .rocket, color: shell.color, delay: burst - climb, lifetime: climb, origin: CGPoint(x: shell.center.x, y: 1),
				velocity: CGVector(dx: 0, dy: (shell.center.y - 1) * rocketDrag / decay), drag: rocketDrag, gravity: 0)
			let sparks = (0..<80).map { _ -> ConfettiParticle in
				// Points on a sphere seen from the front: dense at the rim, filled towards the middle.
				let angle = value(0...(2 * .pi), random)
				let depth = value(-1...1, random)
				let speed = sqrt(1 - depth * depth) * value(0.5...0.56, random)
				return ConfettiParticle(
					shape: .spark, color: value(0...1, random) < 0.18 ? .white : shell.color, delay: burst,
					lifetime: value(1.5...1.9, random), origin: shell.center,
					velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed), drag: 2.4, gravity: 0.45,
					phase: value(0...(2 * .pi), random))
			}
			return [rocket] + sparks
		}
	}

	/// Dresses a launched particle as a piece of paper that sways and tumbles while it falls.
	private static func paper(_ launch: ConfettiParticle, index: Int, random: GKRandomSource) -> ConfettiParticle {
		var particle = launch
		let roll = value(0...1, random)
		particle.shape = roll < 0.55 ? .rectangle : roll < 0.8 ? .circle : .ribbon
		particle.color = palette[index % palette.count]
		particle.lifetime = min(launch.lifetime, duration - launch.delay)
		particle.sway = value(0.01...0.03, random)
		particle.swayRate = value(2.5...6, random)
		particle.flipRate = value(5...13, random)
		particle.spin = value(-5...5, random)
		particle.phase = value(0...(2 * .pi), random)
		particle.scale = value(0.85...1.25, random)
		return particle
	}

	private static func value(_ range: ClosedRange<Double>, _ random: GKRandomSource) -> Double {
		range.lowerBound + Double(random.nextUniform()) * (range.upperBound - range.lowerBound)
	}
}
