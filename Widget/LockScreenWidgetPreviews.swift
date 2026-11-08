import SwiftUI
import WidgetKit

// Leo on an ordinary day, three days before his birthday, on the birthday, nobody pinned, and an unreadable store.

#Preview(as: .accessoryRectangular) {
	GrowingUpLockScreenWidget()
} timeline: {
	LockScreenEntry(date: .now, content: .loaded(LockScreenWidgetProvider.samplePerson()))
	LockScreenEntry(date: .now, content: .loaded(LockScreenWidgetProvider.samplePerson(birthdayInDays: 3)))
	LockScreenEntry(date: .now, content: .loaded(LockScreenWidgetProvider.samplePerson(birthdayInDays: 0)))
	LockScreenEntry(date: .now, content: .nobodyPinned)
	LockScreenEntry(date: .now, content: .unavailable)
}

#Preview("Russian") {
	let entry = LockScreenEntry(date: .now, content: .loaded(LockScreenWidgetProvider.samplePerson(birthdayInDays: 3)))
	LockScreenWidgetContentView(entry: entry)
		.frame(width: 172, height: 76)
		.padding()
		.background(.black)
		.environment(\.locale, Locale(identifier: "ru"))
		.environment(\.colorScheme, .dark)
}
