import SwiftUI

/// A tiny Home Screen in the widget hint: the real medium widget with the user's people above a few placeholder icons.
struct WidgetHintHomeScreen: View {
	/// The pinned people, as the widget shows them; nil while they load.
	let entry: AgeEntry?

	var body: some View {
		GeometryReader { proxy in
			let inset = proxy.size.width * 0.06
			VStack(spacing: inset) {
				Group {
					if let entry {
						WidgetPreview(entry: entry, family: .systemMedium)
					} else {
						RoundedRectangle(cornerRadius: 10, style: .continuous)
							.fill(.white.opacity(0.15))
							.aspectRatio(364 / 170, contentMode: .fit)
					}
				}
				PlaceholderIconGrid(
					count: 8, horizontalSpacing: inset * 1.1, verticalSpacing: inset * 0.9, cornerRadius: inset * 0.7, showsLabels: false
				)
				.padding(.horizontal, inset * 0.3)
			}
			.padding(.horizontal, inset)
			.padding(.top, inset * 1.2)
			.frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
		}
		.background { WidgetGuideWallpaper() }
		.clipShape(.rect(cornerRadius: 18, style: .continuous))
		.accessibilityHidden(true)
	}
}
