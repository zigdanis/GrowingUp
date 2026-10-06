import SwiftUI
import WidgetKit

struct AgeWidgetEntryView: View {
	@Environment(\.widgetFamily)
	private var family
	let entry: AgeEntry

	var body: some View {
		AgeWidgetContentView(entry: entry, family: family)
	}
}
