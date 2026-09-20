#if DEBUG
	import SwiftUI

	struct UITestAppearanceProbe: View {
		@Environment(\.colorScheme)
		private var colorScheme

		var body: some View {
			if UITestComposition.isEnabled {
				Color.clear.frame(width: 1, height: 1)
					.accessibilityElement()
					.accessibilityLabel("Effective appearance")
					.accessibilityIdentifier("test.appearance")
					.accessibilityValue(colorScheme == .dark ? "dark" : "light")
					.allowsHitTesting(false)
			}
		}
	}
#endif
