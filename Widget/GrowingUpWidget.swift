//
//  GrowingUpWidget.swift
//  Widget
//
//  Entry point for the GrowingUp WidgetKit extension.
//

import SwiftUI
import WidgetKit

struct GrowingUpWidget: Widget {
	let kind = "pro.ziganshin.GrowingUp.Widget"

	var body: some WidgetConfiguration {
		// The entry view chooses its container background per family: the person's photo in the small widget.
		// Tiles run edge to edge, so the system's content margins are off; each tile insets its own text.
		StaticConfiguration(kind: kind, provider: AgeWidgetProvider()) { entry in
			AgeWidgetEntryView(entry: entry)
		}
		.configurationDisplayName("GrowingUp")
		.description("See up to six pinned people and their live age.")
		.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
		.contentMarginsDisabled()
	}
}
