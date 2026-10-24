import SwiftUI

/// The mosaic's "glow": a soft mesh of the first people's photo colours that fills the window, under the status bar and
/// the home indicator, in a dark or light variant that follows the colour scheme.
///
/// It stays fixed while the mosaic scrolls, so it costs nothing per frame.
struct AmbientBackground: View {
	/// The average photo colours of the first people in mosaic order; empty for the app-coloured empty mosaic.
	let seeds: [UIColor]
	@Environment(\.colorScheme)
	private var colorScheme

	var body: some View {
		let palette = AmbientPalette(seeds: seeds, colorScheme: colorScheme)
		MeshGradient(width: 4, height: 4, points: AmbientPalette.points, colors: palette.meshColors)
			.animation(.easeInOut(duration: 0.6), value: palette)
			.ignoresSafeArea()
			.accessibilityHidden(true)
	}
}
