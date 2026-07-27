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
				.containerBackground(.fill.tertiary, for: .widget)
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
