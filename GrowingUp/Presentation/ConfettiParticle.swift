import SwiftUI

/// One particle whose state is a closed-form function of time, so any frame can be drawn without stepping a simulation.
///
/// Positions start in unit coordinates of the canvas. Velocity, gravity and sway use canvas heights per second, so the motion
/// keeps its proportions on every screen size.
struct ConfettiParticle {
	var shape: ConfettiShape
	var color: Color
	var delay: TimeInterval
	var lifetime: TimeInterval
	var origin: CGPoint
	var velocity: CGVector
	/// Linear air drag: the launch speed decays quickly, then the particle settles at `gravity / drag`.
	var drag: Double
	var gravity: Double
	var sway = 0.0
	var swayRate = 0.0
	var flipRate = 0.0
	var spin = 0.0
	var phase = 0.0
	var scale = 1.0

	func position(at time: TimeInterval, in size: CGSize) -> CGPoint {
		let decay = 1 - exp(-drag * time)
		let terminal = gravity / drag
		let drift = sway * sin(swayRate * time + phase) * decay
		return CGPoint(
			x: origin.x * size.width + (velocity.dx / drag * decay + drift) * size.height,
			y: origin.y * size.height + (terminal * time + (velocity.dy - terminal) / drag * decay) * size.height)
	}

	func opacity(at time: TimeInterval) -> Double {
		guard time >= 0, time <= lifetime else { return 0 }
		switch shape {
		case .rectangle, .circle, .ribbon:
			return min(1, (lifetime - time) / 0.45)
		case .rocket:
			return 1
		case .spark:
			let fade = pow(1 - time / lifetime, 1.5)
			let twinkle = time > lifetime * 0.45 ? 0.55 + 0.45 * sin(28 * time + phase) : 1
			return fade * twinkle
		}
	}

	/// The cosine of the tumble angle: negative values show the paper's darker back face.
	func flip(at time: TimeInterval) -> Double { cos(flipRate * time + phase) }

	func rotation(at time: TimeInterval) -> Angle { .radians(spin * time + phase) }
}
