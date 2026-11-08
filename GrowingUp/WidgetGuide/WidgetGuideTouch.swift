import SwiftUI

/// A fingertip on an illustrated screen: a soft white dot with two fading rings, which press in while `isPressing`.
struct WidgetGuideTouch: View {
	var isPressing = false

	var body: some View {
		Circle()
			.fill(.white.opacity(0.35))
			.frame(width: 54, height: 54)
			.background { Circle().fill(.white.opacity(0.14)).padding(-10) }
			.background { Circle().fill(.white.opacity(0.06)).padding(isPressing ? -30 : -22) }
			.scaleEffect(isPressing ? 0.88 : 1)
	}
}
