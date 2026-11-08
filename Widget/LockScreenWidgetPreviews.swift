import SwiftUI
import WidgetKit

// Leo on an ordinary day, three days before his birthday, on the birthday, and nobody pinned.

#Preview(as: .accessoryRectangular) {
	GrowingUpLockScreenWidget()
} timeline: {
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson())
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 3))
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 0))
	LockScreenEntry(date: .now, person: nil)
}

#Preview("Russian") {
	let entry = LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 3))
	LockScreenWidgetContentView(entry: entry)
		.frame(width: 172, height: 76)
		.padding()
		.background(.black)
		.environment(\.locale, Locale(identifier: "ru"))
		.environment(\.colorScheme, .dark)
}
