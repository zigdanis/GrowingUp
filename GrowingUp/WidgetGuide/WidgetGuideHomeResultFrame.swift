import SwiftUI

/// The Home Screen tab's result: the medium GrowingUp widget, with the user's people, above the icons.
struct WidgetGuideHomeResultFrame: View {
	let entry: AgeEntry?
	let isAnimated: Bool

	var body: some View {
		WidgetGuideCanvas {
			WidgetGuideHighlightedWidget(entry: entry, family: .systemMedium, isAnimated: isAnimated)
				.frame(width: 353 - 48)
				.offset(x: 24, y: 24)
			PlaceholderIconGrid(count: 8)
				.frame(width: 297)
				.offset(x: 28, y: 188)
		}
	}
}
