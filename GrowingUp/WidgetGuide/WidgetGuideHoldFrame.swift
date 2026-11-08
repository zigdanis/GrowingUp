import SwiftUI

/// Step 1 on the Home Screen: a finger touches and holds an empty spot below the icons.
struct WidgetGuideHoldFrame: View {
	let isAnimated: Bool

	var body: some View {
		WidgetGuideCanvas {
			PlaceholderIconGrid(count: 12)
				.frame(width: 297)
				.offset(x: 28, y: 30)
			touch
				.offset(x: 150, y: 228)
		}
	}

	@ViewBuilder
	private var touch: some View {
		if isAnimated {
			// Presses in, holds, and lets go, again and again.
			PhaseAnimator([false, true]) { isPressing in
				WidgetGuideTouch(isPressing: isPressing)
			} animation: { isPressing in
				isPressing ? .easeIn(duration: 0.5) : .easeOut(duration: 0.4).delay(1)
			}
		} else {
			WidgetGuideTouch(isPressing: true)
		}
	}
}
