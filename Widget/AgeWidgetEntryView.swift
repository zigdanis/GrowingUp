import SwiftUI
import WidgetKit

struct AgeWidgetEntryView: View {
	@Environment(\.widgetFamily)
	private var family
	let entry: AgeEntry

	var body: some View {
		AgeWidgetContentView(entry: entry, family: family)
			.containerBackground(for: .widget) {
				AgeWidgetBackground(entry: entry, family: family)
			}
			// The small widget's photo and its scrim keep the white text legible, so the system must not strip them.
			.containerBackgroundRemovable(family != .systemSmall)
	}
}
