import SwiftUI

/// Invites adding someone when nobody is pinned to the widget; the small widget drops the caption.
struct EmptyWidgetView: View {
	let isCompact: Bool

	var body: some View {
		VStack(spacing: isCompact ? 6 : 10) {
			Image(systemName: "plus")
				.font(.system(size: isCompact ? 16 : 20, weight: .semibold))
				.frame(width: isCompact ? 40 : 52, height: isCompact ? 40 : 52)
				.background { Circle().fill(.primary.opacity(0.1)) }
			Text("Add someone", tableName: "Widget")
				.font(.system(size: isCompact ? 15 : 17, weight: .semibold))
			if !isCompact {
				Text("Choose people in GrowingUp", tableName: "Widget")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.multilineTextAlignment(.center)
		.lineLimit(2)
		.minimumScaleFactor(0.7)
		.padding(16)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.widgetURL(URL(string: "growingup-app://add-person"))
	}
}
