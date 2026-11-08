import SwiftUI

/// A numbered step of the widget guide; the highlighted one is bright, with its number in the app colour, and a tap on
/// any step plays it.
struct WidgetGuideStepRow: View {
	let number: Int
	let title: LocalizedStringKey
	let isHighlighted: Bool
	let action: () -> Void
	@ScaledMetric(relativeTo: .subheadline)
	private var badge: CGFloat = 26

	var body: some View {
		Button(action: action) {
			HStack(alignment: .top, spacing: 12) {
				Text(number, format: .number)
					.font(.subheadline.bold())
					.foregroundStyle(isHighlighted ? Color.white : Color.primary)
					.frame(width: badge, height: badge)
					.background(isHighlighted ? Color(uiColor: .appColor) : Color.primary.opacity(0.15), in: .circle)
				Text(title)
					.font(.body)
					.multilineTextAlignment(.leading)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.opacity(isHighlighted ? 1 : 0.5)
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(isHighlighted ? .isSelected : [])
	}
}
