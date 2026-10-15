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
			// The photo is decorative; the tile carries the label. Hidden, the scaled-to-fill image also cannot report its unclipped frame.
			.accessibilityHidden(true)
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
				placeholderFace
			}
		}
	}

	/// The face sits between the name row and the age text, which fill the top and bottom of a tile, and scales with the container.
	private var placeholderFace: some View {
		GeometryReader { proxy in
			let side = min(proxy.size.width * 0.4, proxy.size.height * 0.24)
			Image("face")
				.resizable()
				.scaledToFit()
				.foregroundStyle(.secondary)
				.frame(width: side, height: side)
				.frame(maxWidth: .infinity)
				.padding(.top, proxy.size.height * 0.18)
		}
	}
}
