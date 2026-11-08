import Core
import SwiftUI

/// Invites to add someone when nobody is pinned; tapping opens the app's editor for a new person.
struct LockScreenEmptyView: View {
	var body: some View {
		Label {
			Text("Add someone", tableName: "Widget")
		} icon: {
			Image(systemName: "person.crop.circle.badge.plus")
		}
		.font(.headline)
		.frame(maxWidth: .infinity, alignment: .leading)
		.widgetURL(URL(string: "growingup-app://\(Constants.widgetAddPersonHost)"))
	}
}
