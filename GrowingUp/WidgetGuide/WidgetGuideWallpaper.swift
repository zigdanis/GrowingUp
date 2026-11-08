import SwiftUI

/// The neutral violet wallpaper of the guide's illustrated Home Screens.
struct WidgetGuideWallpaper: View {
	var body: some View {
		LinearGradient(
			stops: [
				.init(color: Color(red: 0.54, green: 0.48, blue: 0.66), location: 0),
				.init(color: Color(red: 0.35, green: 0.31, blue: 0.47), location: 0.35),
				.init(color: Color(red: 0.23, green: 0.2, blue: 0.31), location: 0.65),
				.init(color: Color(red: 0.16, green: 0.15, blue: 0.22), location: 1)
			], startPoint: .topLeading, endPoint: .bottomTrailing)
	}
}
