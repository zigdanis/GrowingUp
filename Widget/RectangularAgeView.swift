import Core
import SwiftUI
import WidgetKit

/// The name, the age and, when the birthday is near, how many days remain.
struct RectangularAgeView: View {
	let person: WidgetPerson
	let text: LockScreenText
	@Environment(\.widgetRenderingMode)
	private var renderingMode
	@Environment(\.redactionReasons)
	private var redactionReasons

	var body: some View {
		HStack(spacing: 8) {
			// The tinted and vibrant looks flatten photos, so only full color shows one.
			if renderingMode == .fullColor, let image = person.photo {
				Image(uiImage: image).resizable().scaledToFill().frame(width: 36, height: 36).clipShape(Circle())
			}
			VStack(alignment: .leading, spacing: 2) {
				Text(text.name).font(.headline).widgetAccentable()
				Text(text.compactAge).font(.subheadline)
				if let birthdayLine = text.birthdayLine {
					Text(birthdayLine).font(.caption2)
				}
			}
			.lineLimit(1)
			.minimumScaleFactor(0.8)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(redactionReasons.contains(.privacy) ? "GrowingUp" : text.accessibilityLabel)
	}
}
