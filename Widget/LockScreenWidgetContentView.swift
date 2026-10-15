import Core
import SwiftUI
import WidgetKit

/// The Lock Screen widget for an explicit family, so the app's UI-test harness can render every family.
struct LockScreenWidgetContentView: View {
	let entry: LockScreenEntry
	let family: WidgetFamily
	@Environment(\.locale)
	private var locale

	var body: some View {
		if let person = entry.person {
			// Accessory widgets cannot hold links, so the whole widget opens the person.
			ageView(person, text: LockScreenText(name: person.name, birthday: person.birthday, now: entry.date, locale: locale))
				.widgetURL(person.deepLinkURL)
		} else {
			LockScreenEmptyView(family: family)
		}
	}

	@ViewBuilder
	private func ageView(_ person: WidgetPerson, text: LockScreenText) -> some View {
		switch family {
		case .accessoryCircular:
			CircularAgeView(person: person, text: text)
		case .accessoryInline:
			InlineAgeView(text: text)
		default:
			RectangularAgeView(person: person, text: text)
		}
	}
}
