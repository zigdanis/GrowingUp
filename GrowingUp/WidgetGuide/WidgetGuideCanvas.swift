import SwiftUI

/// One frame of the widget guide's illustration, drawn on a fixed 353 × 300 point screen and scaled to the width it is
/// given, so every frame keeps its proportions on any device and at any text size.
struct WidgetGuideCanvas<Content: View>: View {
	/// The size every frame is drawn at.
	private let size = CGSize(width: 353, height: 300)
	private let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		Color.clear
			.aspectRatio(size.width / size.height, contentMode: .fit)
			.overlay(alignment: .topLeading) {
				GeometryReader { proxy in
					ZStack(alignment: .topLeading) {
						WidgetGuideWallpaper()
						content
					}
					.frame(width: size.width, height: size.height, alignment: .topLeading)
					.clipShape(.rect(cornerRadius: 26, style: .continuous))
					.environment(\.colorScheme, .dark)
					.scaleEffect(proxy.size.width / size.width, anchor: .topLeading)
				}
			}
	}
}
