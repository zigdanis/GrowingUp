import SwiftUI

struct EmptyWidgetView: View {
	var body: some View {
		VStack(spacing: 8) {
			Image(systemName: "person.crop.circle.badge.plus").font(.title).foregroundStyle(.secondary)
			Text("Add a person").font(.caption).foregroundStyle(.secondary)
		}
		.widgetURL(URL(string: "growingup-app://add-person"))
	}
}
