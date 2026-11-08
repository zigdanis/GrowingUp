//
//  GrowingUpLockScreenWidget.swift
//  Widget
//
//  The Lock Screen and StandBy widget with the name, age and next birthday of the
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
		.supportedFamilies([.accessoryRectangular])
	}
}
