import Core
import SwiftUI
import WidgetKit

/// The name, the age and, when the birthday is near, how many days remain.
///
/// It shows no picture: the Lock Screen's vibrant look renders photos grey.
struct RectangularAgeView: View {
	let text: LockScreenText
	@Environment(\.redactionReasons)
	private var redactionReasons

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(text.name).font(.headline).widgetAccentable()
			Text(text.compactAge).font(.subheadline)
			if let birthdayLine = text.birthdayLine {
				Text(birthdayLine).font(.caption2)
			}
		}
		.lineLimit(1)
		.minimumScaleFactor(0.8)
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(redactionReasons.contains(.privacy) ? String(localized: "GrowingUp") : text.accessibilityLabel)
	}
}
