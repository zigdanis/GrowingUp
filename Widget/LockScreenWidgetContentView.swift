import Core
import SwiftUI

/// The Lock Screen widget, so the app's UI-test harness can render it outside WidgetKit.
struct LockScreenWidgetContentView: View {
	let entry: LockScreenEntry
	@Environment(\.locale)
	private var locale

	var body: some View {
		switch entry.content {
		case .loaded(let person):
			// Accessory widgets cannot hold links, so the whole widget opens the person.
			RectangularAgeView(text: LockScreenText(name: person.name, birthday: person.birthday, now: entry.date, locale: locale))
				.privacySensitive()
				.widgetURL(person.deepLinkURL)
		case .nobodyPinned:
			LockScreenEmptyView()
		case .unavailable:
			LockScreenUnavailableView()
		}
	}
}
