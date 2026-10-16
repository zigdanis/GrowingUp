import Core
import SwiftUI
import WidgetKit

/// A ring that fills up from one birthday to the next around the age, with a cake on the birthday itself.
struct CircularAgeView: View {
	let text: LockScreenText
	@Environment(\.redactionReasons)
	private var redactionReasons

	var body: some View {
		ZStack {
			// The gauge style draws its own track; the label and value are laid out above it, so the age always shows.
			Gauge(value: text.yearProgress) {
				EmptyView()
			}
			.gaugeStyle(.accessoryCircularCapacity)
			.widgetAccentable()
			VStack(spacing: -2) {
				if text.isBirthday {
					Image(systemName: "birthday.cake.fill").font(.title3)
				} else {
					Text(text.primaryValue).font(.system(.title3, design: .rounded, weight: .bold))
					Text(text.primaryUnitAbbreviation).font(.system(size: 9, weight: .semibold))
				}
			}
			.lineLimit(1)
			.minimumScaleFactor(0.5)
			.padding(10)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(redactionReasons.contains(.privacy) ? "GrowingUp" : text.accessibilityLabel)
	}
}
