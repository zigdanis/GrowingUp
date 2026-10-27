import SwiftUI

/// The glass behind the edit mode's controls, in `shape`: Liquid Glass where available, else a dark material with a
/// hairline edge, so white titles and glyphs read over any photo.
struct EditModeGlass<GlassShape: Shape>: View {
	let shape: GlassShape

	var body: some View {
		#if compiler(>=6.2)
			if #available(iOS 26.0, *) {
				Color.clear.glassEffect(.regular, in: shape)
			} else {
				legacy
			}
		#else
			legacy
		#endif
	}

	private var legacy: some View {
		ZStack {
			shape.fill(.black.opacity(0.25))
			shape.fill(.ultraThinMaterial)
		}
		.overlay { shape.stroke(.white.opacity(0.5), lineWidth: 1) }
		.shadow(color: .black.opacity(0.3), radius: 4, y: 1)
	}
}
