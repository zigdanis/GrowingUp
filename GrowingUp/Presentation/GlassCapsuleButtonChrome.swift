import SwiftUI

/// Applies capsule Liquid Glass chrome to a text button when available, with the bordered styles as the fallback.
struct GlassCapsuleButtonChrome: ViewModifier {
	let prominent: Bool

	func body(content: Content) -> some View {
		Group {
			#if compiler(>=6.2)
				if #available(iOS 26.0, *) {
					if prominent { content.buttonStyle(.glassProminent) } else { content.buttonStyle(.glass) }
				} else {
					legacyChrome(content)
				}
			#else
				legacyChrome(content)
			#endif
		}
		.buttonBorderShape(.capsule)
	}

	@ViewBuilder
	private func legacyChrome(_ content: Content) -> some View {
		if prominent { content.buttonStyle(.borderedProminent) } else { content.buttonStyle(.bordered) }
	}
}
