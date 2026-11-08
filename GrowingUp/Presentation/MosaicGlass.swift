import SwiftUI

/// The glass of a card that sits among the mosaic's tiles, in `shape`: Liquid Glass where available, else a material
/// with a hairline edge. Unlike the edit mode's glass, which lies on photos, it follows the mosaic's light or dark look.
struct MosaicGlass<GlassShape: Shape>: View {
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
		shape.fill(.regularMaterial)
			.overlay { shape.stroke(.primary.opacity(0.12), lineWidth: 1) }
	}
}
