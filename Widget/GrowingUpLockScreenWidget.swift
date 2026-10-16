//
//  GrowingUpLockScreenWidget.swift
//  Widget
//
//  Lock Screen and StandBy widgets with the age and next birthday of the
//  first pinned person.
//

import SwiftUI
import WidgetKit

struct GrowingUpLockScreenWidget: Widget {
	let kind = "pro.ziganshin.GrowingUp.LockScreenWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: LockScreenWidgetProvider()) { entry in
			LockScreenWidgetEntryView(entry: entry)
				.containerBackground(for: .widget) { Color.clear }
		}
		.configurationDisplayName("GrowingUp")
		.description("Age and next birthday of your first pinned person.")
		.supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
	}
}
