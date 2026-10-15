import SwiftUI
import WidgetKit

/// The whole widget's background: the person's photo in the small family, a neutral fill around tiles and the empty state.
///
/// The extension installs it as the WidgetKit container background; the UI-test preview, which runs outside WidgetKit,
/// draws it as a plain background so it shows the same design.
struct AgeWidgetBackground: View {
	let entry: AgeEntry
	let family: WidgetFamily

	var body: some View {
		if family == .systemSmall, let person = entry.persons.first {
			PersonPhotoBackground(image: person.image)
		} else {
			Rectangle().fill(.fill.tertiary)
		}
	}
}
