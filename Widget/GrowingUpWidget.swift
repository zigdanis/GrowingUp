//
//  GrowingUpWidget.swift
//  Widget
//
//  Entry point for the GrowingUp WidgetKit extension.
//

import WidgetKit
import SwiftUI

struct GrowingUpWidget: Widget {
	let kind = "pro.ziganshin.GrowingUp.Widget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: AgeWidgetProvider()) { entry in
			AgeWidgetEntryView(entry: entry)
				.widgetContainerBackground()
		}
		.configurationDisplayName("GrowingUp")
		.description("See your pinned people and their live age.")
		.supportedFamilies([.systemSmall, .systemMedium])
	}
}

@main
struct GrowingUpWidgetBundle: WidgetBundle {
	var body: some Widget {
		GrowingUpWidget()
	}
}

private extension View {
	/// iOS 17+ requires `containerBackground` for home-screen widgets; on iOS 16
	/// the system provides the background, so this is a no-op there.
	@ViewBuilder
	func widgetContainerBackground() -> some View {
		if #available(iOS 17.0, *) {
			containerBackground(.fill.tertiary, for: .widget)
		} else {
			self
		}
	}
}
