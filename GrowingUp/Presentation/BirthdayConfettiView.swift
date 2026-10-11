import SwiftUI

struct BirthdayConfettiView: View {
	let started: Date
	private let colors: [Color] = [.pink, .yellow, .cyan, .orange, .green, .purple]

	var body: some View {
		TimelineView(.animation) { timeline in
			Canvas { context, size in
				let elapsed = timeline.date.timeIntervalSince(started)
				for index in 0..<100 {
					let time = elapsed - Double(index % 10) * 0.025
					guard time >= 0 else { continue }
					let fromLeft = index.isMultiple(of: 2)
					let spread = Double((index * 37) % 100) / 100
					let speed = size.width * (0.3 + spread * 0.32)
					let horizontal = speed * time
					let vertical = size.height * (0.48 - (0.55 + spread * 0.35) * time + 0.42 * time * time)
					var particle = context
					particle.opacity = min(1, max(0, 3.5 - elapsed))
					particle.translateBy(x: fromLeft ? horizontal : size.width - horizontal, y: vertical)
					particle.rotate(by: .radians(time * (4 + spread * 7) + Double(index)))
					let rect = CGRect(x: -4, y: -7, width: 8, height: 14)
					particle.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(colors[index % colors.count]))
				}
			}
		}
	}
}
