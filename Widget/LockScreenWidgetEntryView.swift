import SwiftUI

struct LockScreenWidgetEntryView: View {
	let entry: LockScreenEntry

	var body: some View {
		LockScreenWidgetContentView(entry: entry)
	}
}
