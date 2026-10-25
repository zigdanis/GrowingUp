import SwiftUI

/// The reordering mosaic's tiles rocking gently, each at its own pace, like the Home Screen's icons; still with Reduce
/// Motion on.
///
/// The rocking always wraps the tile, only paused when inactive, so starting it never rebuilds the tile and its gestures.
struct MosaicWiggle: ViewModifier {
	let isActive: Bool
	/// Varies the pace and phase per tile, so the mosaic does not rock in step.
	let seed: Int
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	func body(content: Content) -> some View {
		let isRocking = isActive && !reduceMotion
		TimelineView(.animation(paused: !isRocking)) { context in
			content.rotationEffect(.degrees(isRocking ? angle(at: context.date) : 0))
		}
	}

	/// About 1.2° either way, around four times a second.
	private func angle(at date: Date) -> Double {
		let variation = Double(abs(seed) % 7) / 7
		let frequency = 3.6 + variation * 0.8
		return 1.2 * sin(2 * .pi * (date.timeIntervalSinceReferenceDate * frequency + variation))
	}
}
