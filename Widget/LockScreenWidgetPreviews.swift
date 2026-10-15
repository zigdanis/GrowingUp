import SwiftUI
import WidgetKit

// Leo on an ordinary day, three days before his birthday, on the birthday, and nobody pinned.

#Preview(as: .accessoryCircular) {
	GrowingUpLockScreenWidget()
} timeline: {
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson())
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 3))
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 0))
	LockScreenEntry(date: .now, person: nil)
}

#Preview(as: .accessoryRectangular) {
	GrowingUpLockScreenWidget()
} timeline: {
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson())
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 3))
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 0))
	LockScreenEntry(date: .now, person: nil)
}

#Preview(as: .accessoryInline) {
	GrowingUpLockScreenWidget()
} timeline: {
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson())
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 3))
	LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 0))
	LockScreenEntry(date: .now, person: nil)
}

#Preview("Russian") {
	let entry = LockScreenEntry(date: .now, person: LockScreenWidgetProvider.samplePerson(birthdayInDays: 3))
	VStack(spacing: 24) {
		LockScreenWidgetContentView(entry: entry, family: .accessoryCircular).frame(width: 76, height: 76)
		LockScreenWidgetContentView(entry: entry, family: .accessoryRectangular).frame(width: 172, height: 76)
		LockScreenWidgetContentView(entry: entry, family: .accessoryInline).frame(width: 257, height: 26)
	}
	.padding()
	.background(.black)
	.environment(\.locale, Locale(identifier: "ru"))
	.environment(\.colorScheme, .dark)
}
