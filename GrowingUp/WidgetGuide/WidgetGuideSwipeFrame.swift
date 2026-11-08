import SwiftUI

/// Step 1 for the Today View: a finger swipes right across the first Home Screen page.
struct WidgetGuideSwipeFrame: View {
	let isAnimated: Bool

	var body: some View {
		WidgetGuideCanvas {
			PlaceholderIconGrid(count: 12)
				.frame(width: 297)
				.offset(x: 28, y: 30)
			if isAnimated {
				// The finger travels from the left to the right, leaving a fading trail, again and again.
				PhaseAnimator([CGFloat(0), 1]) { progress in
					swipe(progress: progress)
				} animation: { progress in
					progress == 1 ? .easeInOut(duration: 1.1) : .linear(duration: 0.01).delay(0.5)
				}
			} else {
				swipe(progress: 1)
			}
		}
	}

	private func swipe(progress: CGFloat) -> some View {
		ZStack(alignment: .topLeading) {
			Capsule()
				.fill(LinearGradient(colors: [.clear, .white.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
				.frame(width: 20 + 180 * progress, height: 10)
				.offset(x: 70, y: 236)
			WidgetGuideTouch()
				.offset(x: 70 + 180 * progress, y: 214)
		}
		.opacity(progress == 0 ? 0.4 : 1)
	}
}
