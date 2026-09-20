import SwiftUI

/// Applies Liquid Glass button chrome when available, with a legacy fallback.
struct GlassButtonChrome: ViewModifier {
	let prominent: Bool

	func body(content: Content) -> some View {
		#if compiler(>=6.2)
			if #available(iOS 26.0, *) {
				Group {
					if prominent { content.buttonStyle(.glassProminent) } else { content.buttonStyle(.glass) }
				}
				.buttonBorderShape(.circle)
				.tint(prominent ? Color.accentColor : nil)
			} else {
				legacyChrome(content)
			}
		#else
			legacyChrome(content)
		#endif
	}

	@ViewBuilder
	private func legacyChrome(_ content: Content) -> some View {
		content
			.buttonStyle(.plain)
			.foregroundStyle(.white)
			.background {
				if prominent {
					Circle().fill(Color.accentColor)
				} else {
					ZStack {
						Circle().fill(.black.opacity(0.25))
						Circle().fill(.ultraThinMaterial)
					}
				}
			}
			.overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
			.shadow(color: .black.opacity(0.3), radius: 4, y: 1)
	}
}
