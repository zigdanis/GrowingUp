import SwiftUI

/// Plays the failure haptic as a scene's error alert comes up.
struct SceneErrorHaptics: ViewModifier {
	let isShown: Bool
	@Environment(\.haptics)
	private var haptics

	func body(content: Content) -> some View {
		content.onChange(of: isShown) { _, shown in
			if shown { haptics.play(.failure) }
		}
	}
}
