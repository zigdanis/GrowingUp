import Core
import SwiftUI
import WidgetKit

/// Invites to add someone when nobody is pinned; tapping opens the app's editor for a new person.
struct LockScreenEmptyView: View {
	let family: WidgetFamily

	var body: some View {
		content
			.widgetURL(URL(string: "growingup-app://\(Constants.widgetAddPersonHost)"))
	}

	@ViewBuilder private var content: some View {
		switch family {
		case .accessoryCircular:
			ZStack {
				AccessoryWidgetBackground()
				Image(systemName: "person.crop.circle.badge.plus").font(.title2)
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(Text("Add someone", tableName: "Widget"))
		case .accessoryInline:
			invitation
		default:
			invitation
				.font(.headline)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	private var invitation: some View {
		Label {
			Text("Add someone", tableName: "Widget")
		} icon: {
			Image(systemName: "person.crop.circle.badge.plus")
		}
	}
}
