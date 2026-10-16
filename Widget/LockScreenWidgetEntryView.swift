import SwiftUI
import WidgetKit

struct LockScreenWidgetEntryView: View {
	@Environment(\.widgetFamily)
	private var family
	let entry: LockScreenEntry

	var body: some View {
		LockScreenWidgetContentView(entry: entry, family: family)
	}
}
