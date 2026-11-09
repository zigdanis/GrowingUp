import SwiftUI

/// The Settings row that opens the Home Screen widget guide, the lasting home of the once-only hint on the mosaic.
struct SettingsWidgetSection: View {
	let onOpen: () -> Void

	var body: some View {
		Section {
			Button(action: onOpen) {
				Label("Home Screen widget", systemImage: "square.grid.2x2")
			}
			.accessibilityIdentifier("settings.widgetGuide")
		} footer: {
			Text("How to add the widget with your people's photos and ages to your Home Screen or Today View.")
		}
	}
}
