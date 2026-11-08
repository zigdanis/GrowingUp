import SwiftUI

/// Stands in for the first pinned person while the shared store cannot be read; the widget retries by itself.
struct LockScreenUnavailableView: View {
	var body: some View {
		Label {
			Text("Back soon", tableName: "Widget")
		} icon: {
			Image(systemName: "clock")
		}
		.font(.headline)
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text("Ages will be back soon", tableName: "Widget"))
	}
}
