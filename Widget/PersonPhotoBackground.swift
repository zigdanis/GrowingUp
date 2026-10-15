import SwiftUI
import UIKit
import WidgetKit

/// A person's widget photo filling its container, with scrims that keep white text readable on any photo.
struct PersonPhotoBackground: View {
	let image: UIImage?
	@Environment(\.widgetRenderingMode)
	private var renderingMode

	var body: some View {
		Color.clear
			.overlay { photo }
			.overlay {
				// Tinted and clear Home Screens draw views as alpha masks, where the scrims would only haze the photo.
				if renderingMode == .fullColor {
					LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
					LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
				}
			}
			.clipped()
	}

	@ViewBuilder private var photo: some View {
		if let image {
			Image(uiImage: image)
				.resizable()
				.widgetAccentedRenderingMode(.fullColor)
				.scaledToFill()
		} else {
			ZStack {
				Rectangle().fill(.fill.tertiary)
				Image("face").resizable().scaledToFit().foregroundStyle(.secondary).padding(20)
			}
		}
	}
}
