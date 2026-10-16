import SwiftUI

/// Applies Liquid Glass button chrome when available, with a legacy fallback.
struct GlassButtonChrome: ViewModifier {
	let prominent: Bool
	/// The chrome's outline; the legacy fallback draws capsules and, for any other shape, circles.
	var shape: ButtonBorderShape = .circle

	func body(content: Content) -> some View {
		#if compiler(>=6.2)
			if #available(iOS 26.0, *) {
				Group {
					if prominent { content.buttonStyle(.glassProminent) } else { content.buttonStyle(.glass) }
				}
				.buttonBorderShape(shape)
				.tint(prominent ? Color.accentColor : nil)
			} else {
				legacyChrome(content)
			}
		#else
			legacyChrome(content)
		#endif
	}

	private var legacyShape: AnyShape {
		shape == .capsule ? AnyShape(Capsule()) : AnyShape(Circle())
	}

	@ViewBuilder
	private func legacyChrome(_ content: Content) -> some View {
		content
			.buttonStyle(.plain)
			.foregroundStyle(.white)
			.background {
				if prominent {
					legacyShape.fill(Color.accentColor)
				} else {
					ZStack {
						legacyShape.fill(.black.opacity(0.25))
						legacyShape.fill(.ultraThinMaterial)
					}
				}
			}
			.overlay(legacyShape.stroke(.white.opacity(0.5), lineWidth: 1))
			.shadow(color: .black.opacity(0.3), radius: 4, y: 1)
	}
}
