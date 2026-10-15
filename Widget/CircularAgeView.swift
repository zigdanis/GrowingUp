import Core
import SwiftUI
import WidgetKit

/// A ring that fills up from one birthday to the next around the age, with a cake on the birthday itself.
struct CircularAgeView: View {
	let person: WidgetPerson
	let text: LockScreenText
	@Environment(\.widgetRenderingMode)
	private var renderingMode

	var body: some View {
		ZStack {
			AccessoryWidgetBackground()
			// The ring alone: its label and value are laid out below, so the photo and the age always show.
			Gauge(value: text.yearProgress) {
				EmptyView()
			}
			.gaugeStyle(.accessoryCircularCapacity)
			.widgetAccentable()
			VStack(spacing: -2) {
				face
				if text.isBirthday {
					Image(systemName: "birthday.cake.fill").font(.title3).padding(.top, 2)
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
		.accessibilityLabel(text.accessibilityLabel)
	}

	/// The photo only in full color; the tinted and vibrant looks flatten photos, so they show the initial.
	@ViewBuilder private var face: some View {
		if renderingMode == .fullColor, let image = person.photo {
			Image(uiImage: image).resizable().scaledToFill().frame(width: 16, height: 16).clipShape(Circle()).privacySensitive()
		} else {
			Text(text.initial).font(.system(size: 10, weight: .semibold)).privacySensitive()
		}
	}
}
