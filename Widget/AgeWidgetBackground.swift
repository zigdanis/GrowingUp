import SwiftUI
import WidgetKit

/// The whole widget's background: the person's photo in the small family, the seams between tiles, and a soft gradient
/// behind the empty state.
///
/// The extension installs it as the WidgetKit container background; the UI-test preview, which runs outside WidgetKit,
/// draws it as a plain background so it shows the same design.
struct AgeWidgetBackground: View {
	let entry: AgeEntry
	let family: WidgetFamily
	@Environment(\.colorScheme)
	private var colorScheme

	var body: some View {
		if let person = entry.persons.first {
			if family == .systemSmall {
				PersonPhotoBackground(person: person)
			} else {
				Color(uiColor: .systemBackground)
			}
		} else {
			LinearGradient(colors: emptyColors, startPoint: .topLeading, endPoint: .bottomTrailing)
		}
	}

	private var emptyColors: [Color] {
		colorScheme == .dark
			? [Color(red: 0.08, green: 0.19, blue: 0.17), Color(red: 0.12, green: 0.13, blue: 0.25)]
			: [Color(red: 0.86, green: 0.92, blue: 0.9), Color(red: 0.89, green: 0.88, blue: 0.95)]
	}
}
