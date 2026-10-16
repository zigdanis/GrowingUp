import SwiftUI

/// Applies a Liquid Glass card background when available, with a darkened material fallback.
struct GlassCardChrome: ViewModifier {
	let cornerRadius: CGFloat

	func body(content: Content) -> some View {
		#if compiler(>=6.2)
			if #available(iOS 26.0, *) {
				content.glassEffect(.regular.tint(.black.opacity(0.2)), in: shape)
			} else {
				legacyChrome(content)
			}
		#else
			legacyChrome(content)
		#endif
	}

	private var shape: RoundedRectangle {
		RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
	}

	private func legacyChrome(_ content: Content) -> some View {
		content
			.background {
				ZStack {
					shape.fill(.ultraThinMaterial)
					shape.fill(.black.opacity(0.25))
				}
			}
			.overlay { shape.strokeBorder(.white.opacity(0.15), lineWidth: 1) }
	}
}
