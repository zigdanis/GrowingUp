import SwiftUI

/// Fades over the scrolled mosaic behind the status bar and the home indicator, so both stay legible over any photo.
struct MosaicEdgeScrims: View {
	/// The window's safe area, whose top and bottom edges the fades cover.
	let safeAreaInsets: EdgeInsets
	@Environment(\.colorScheme)
	private var colorScheme

	var body: some View {
		let shade = colorScheme == .dark ? Color.black.opacity(0.45) : Color.white.opacity(0.6)
		VStack(spacing: 0) {
			LinearGradient(colors: [shade, .clear], startPoint: .top, endPoint: .bottom)
				.frame(height: safeAreaInsets.top + 16)
			Spacer(minLength: 0)
			LinearGradient(colors: [.clear, shade], startPoint: .top, endPoint: .bottom)
				.frame(height: safeAreaInsets.bottom + 16)
		}
		.ignoresSafeArea()
		.allowsHitTesting(false)
		.accessibilityHidden(true)
	}
}
