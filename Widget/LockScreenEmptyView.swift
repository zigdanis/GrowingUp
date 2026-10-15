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
			.accessibilityLabel(Text("Add someone"))
		case .accessoryInline:
			Label("Add someone", systemImage: "person.crop.circle.badge.plus")
		default:
			Label("Add someone", systemImage: "person.crop.circle.badge.plus")
				.font(.headline)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}
