import SwiftUI

/// Stands in for the pinned people while the shared store cannot be read, such as before the first unlock after a
/// restart. Nothing is asked of the user: the widget retries by itself, and a tap opens the app as usual.
struct UnavailableWidgetView: View {
	let isCompact: Bool

	var body: some View {
		VStack(spacing: isCompact ? 6 : 10) {
			Image(systemName: "clock")
				.font(.system(size: isCompact ? 16 : 20, weight: .semibold))
				.frame(width: isCompact ? 40 : 52, height: isCompact ? 40 : 52)
				.background { Circle().fill(.primary.opacity(0.1)) }
			Text("Ages will be back soon", tableName: "Widget")
				.font(.system(size: isCompact ? 15 : 17, weight: .semibold))
			if !isCompact {
				Text("The widget refreshes by itself.", tableName: "Widget")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.multilineTextAlignment(.center)
		.lineLimit(2)
		.minimumScaleFactor(0.7)
		.padding(16)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text("Ages will be back soon. The widget refreshes by itself.", tableName: "Widget"))
	}
}
