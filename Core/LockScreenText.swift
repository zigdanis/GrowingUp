import Foundation

/// The Lock Screen reading of one person at one moment: who it is, how old they are and how close their birthday is.
///
/// It is derived from `AgeSummary` and `BirthdayStatus`, so the Lock Screen agrees with the app and the Home Screen
/// widgets. The age never shows minutes or seconds: it counts down to days, or to hours on the day of birth, which
/// reads "0 hours" during the first hour of life. The day of birth itself is not a birthday.
public struct LockScreenText: Equatable, Sendable {
	/// How many days ahead the rectangular widget adds a birthday line.
	public static let birthdayLineDays = 30

	public let name: String
	/// The age in its two largest units, such as "5 years, 3 months".
	public let compactAge: String
	/// "Birthday today 🎂" on the birthday, "Birthday in 12 days" up to `birthdayLineDays` ahead, otherwise `nil`.
	public let birthdayLine: String?
	/// The name, the age and the birthday line for VoiceOver, starting with the name.
	public let accessibilityLabel: String

	public init(name: String, birthday: Date, now: Date, locale: Locale = .current, calendar: Calendar = .current) {
		let finestUnit = Self.finestUnit(birthday: birthday, now: now, calendar: calendar)
		let age = AgeSummary(birthday: birthday, now: now, finestUnit: finestUnit, calendar: calendar)
		let status = BirthdayStatus(birthday: birthday, now: now, calendar: calendar)
		let turningAge = Self.turningAge(on: status.date, birthday: birthday, calendar: calendar)
		// The day of birth, and any day before it, has no birthday to count down to or celebrate.
		let hasBirthday = turningAge > 0
		let isBirthday = hasBirthday && status.isToday
		let birthdayLine: String?
		if isBirthday {
			birthdayLine = Self.localized("Birthday today", locale: locale)
		} else if hasBirthday, (1...Self.birthdayLineDays).contains(status.daysRemaining) {
			birthdayLine = Self.localized("Birthday in %li days", locale: locale, status.daysRemaining)
		} else {
			birthdayLine = nil
		}
		let compactAge = age.localizedCompact(locale: locale)
		self.name = name
		self.compactAge = compactAge
		self.birthdayLine = birthdayLine
		accessibilityLabel = ([name, compactAge] + [birthdayLine].compactMap { $0 }).joined(separator: ", ")
	}

	/// The finest unit the Lock Screen counts in at `now`: days, or hours while the person is less than a day old.
	static func finestUnit(birthday: Date, now: Date, calendar: Calendar) -> AgeUnit {
		AgeSummary(birthday: birthday, now: now, finestUnit: .days, calendar: calendar).primary.value > 0 ? .days : .hours
	}

	/// The age reached on the birthday `date`, so a February 29 birthday celebrated on February 28 still counts a year.
	private static func turningAge(on date: Date, birthday: Date, calendar: Calendar) -> Int {
		let dayAfter = calendar.date(byAdding: .day, value: 1, to: date) ?? date
		return calendar.dateComponents([.year], from: calendar.startOfDay(for: birthday), to: dayAfter).year ?? 0
	}

	/// Formats Core's string `key` in the language of `locale`, with the plural rules of its `Localizable.stringsdict`.
	///
	/// English keys are valid formats, so a missing translation still reads correctly in English.
	private static func localized(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
		String(format: localizedFormat(key, locale: locale), locale: locale, arguments: arguments)
	}

	/// Looks `key` up in Core's localization for the language of `locale`, or in English when Core has none for it.
	private static func localizedFormat(_ key: String, locale: Locale) -> String {
		guard let bundle = Bundle(identifier: Constants.bundleIdentifier) else { return key }
		let language = locale.language.languageCode?.identifier ?? ""
		let localization: String? = bundle.localizations.contains(language) ? language : bundle.developmentLocalization
		let table = localization.flatMap { bundle.path(forResource: $0, ofType: "lproj") }.flatMap(Bundle.init(path:)) ?? bundle
		return table.localizedString(forKey: key, value: nil, table: nil)
	}
}
