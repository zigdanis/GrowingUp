import SwiftUI

/// Invites adding someone when nobody is pinned to the widget.
struct EmptyWidgetView: View {
	var body: some View {
		VStack(spacing: 8) {
			Image(systemName: "person.crop.circle.badge.plus")
				.font(.system(size: 34))
				.foregroundStyle(.secondary)
			Text("Add someone", tableName: "Widget")
				.font(.footnote.weight(.semibold))
				.multilineTextAlignment(.center)
				.lineLimit(2)
				.minimumScaleFactor(0.7)
		}
		.padding(12)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(.fill.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		.widgetURL(URL(string: "growingup-app://add-person"))
	}
}
