import SwiftUI

/// Tilts an icon by `tilt` degrees, rocking it to the other side and back while `isAnimated`.
struct IconRocking: ViewModifier {
	let tilt: Double
	let isAnimated: Bool

	func body(content: Content) -> some View {
		if isAnimated {
			content.phaseAnimator([tilt, -tilt]) { view, angle in
				view.rotationEffect(.degrees(angle))
			} animation: { _ in
				.easeInOut(duration: 0.14)
			}
		} else {
			content.rotationEffect(.degrees(tilt))
		}
	}
}
