import SwiftUI

/// The Today View tab's result: the large GrowingUp widget, with the user's people, under today's date.
struct WidgetGuideTodayResultFrame: View {
	let entry: AgeEntry?
	let date: Date
	let isAnimated: Bool

	var body: some View {
		WidgetGuideCanvas {
			LinearGradient(
				colors: [Color(red: 0.35, green: 0.31, blue: 0.44), Color(red: 0.17, green: 0.15, blue: 0.22)], startPoint: .topLeading,
				endPoint: .bottomTrailing)
			Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(.white.opacity(0.8))
				.offset(x: 18, y: 14)
			RoundedRectangle(cornerRadius: 10)
				.fill(.white.opacity(0.14))
				.frame(width: 353 - 36, height: 30)
				.offset(x: 18, y: 40)
			WidgetGuideHighlightedWidget(entry: entry, family: .systemLarge, isAnimated: isAnimated)
				.frame(width: 353 - 124)
				.offset(x: 62, y: 84)
		}
	}
}
