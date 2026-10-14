import SwiftUI

struct BirthdayConfettiView: View {
	let started: Date
	private let particles: [ConfettiParticle]

	init(started: Date, celebration: Int) {
		self.started = started
		particles = ConfettiStyle(celebration: celebration).particles(seed: UInt64(max(celebration, 0)))
	}

	var body: some View {
		TimelineView(.animation) { timeline in
			Canvas { context, size in
				let elapsed = timeline.date.timeIntervalSince(started)
				for particle in particles {
					let time = elapsed - particle.delay
					guard particle.opacity(at: time) > 0 else { continue }
					switch particle.shape {
					case .rectangle, .circle, .ribbon: drawPaper(particle, at: time, in: context, size: size)
					case .rocket, .spark: drawLight(particle, at: time, in: context, size: size)
					}
				}
			}
		}
	}

	private func drawPaper(_ particle: ConfettiParticle, at time: TimeInterval, in context: GraphicsContext, size: CGSize) {
		var paper = context
		paper.opacity = particle.opacity(at: time)
		let position = particle.position(at: time, in: size)
		paper.translateBy(x: position.x, y: position.y)
		paper.rotate(by: particle.rotation(at: time))
		// Squash along one axis to fake the paper tumbling in 3D; never fully flat so it doesn't vanish mid-turn.
		let flip = particle.flip(at: time)
		paper.scaleBy(x: 1, y: flip < 0 ? min(flip, -0.08) : max(flip, 0.08))
		let scale = particle.scale
		let color = flip < 0 ? particle.color.mix(with: .black, by: 0.32) : particle.color
		switch particle.shape {
		case .circle:
			let radius = 5 * scale
			paper.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius)), with: .color(color))
		case .ribbon:
			var ribbon = Path()
			for step in 0...8 {
				let point = CGPoint(
					x: sin(Double(step) * 0.9 + time * 8 + particle.phase) * 3.5 * scale, y: (-13 + Double(step) * 3.25) * scale)
				if step == 0 { ribbon.move(to: point) } else { ribbon.addLine(to: point) }
			}
			paper.stroke(ribbon, with: .color(color), style: StrokeStyle(lineWidth: 3.6 * scale, lineCap: .round, lineJoin: .round))
		case .rectangle, .rocket, .spark:
			paper.fill(Path(CGRect(x: -6.5 * scale, y: -4.5 * scale, width: 13 * scale, height: 9 * scale)), with: .color(color))
		}
	}

	private func drawLight(_ particle: ConfettiParticle, at time: TimeInterval, in context: GraphicsContext, size: CGSize) {
		var light = context
		let opacity = particle.opacity(at: time)
		light.blendMode = .plusLighter
		let isRocket = particle.shape == .rocket
		let trail = isRocket ? 10 : 6
		// Older positions along the same path form the trail; the newest one is the bright head.
		for step in stride(from: trail - 1, through: 0, by: -1) {
			let point = particle.position(at: max(0, time - Double(step) * (isRocket ? 0.008 : 0.03)), in: size)
			let fraction = Double(step) / Double(trail)
			let radius = step == 0 ? 3.2 : (isRocket ? 3 - Double(step) * 0.2 : 2.2)
			light.opacity = opacity * (step == 0 ? 1 : (isRocket ? 0.9 : 0.35) * (1 - fraction))
			let color = step == 0 && isRocket ? Color.white : particle.color
			light.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(color))
		}
		guard !isRocket else { return }
		let head = particle.position(at: time, in: size)
		light.opacity = opacity * 0.25
		light.fill(Path(ellipseIn: CGRect(x: head.x - 9, y: head.y - 9, width: 18, height: 18)), with: .color(particle.color))
	}
}
