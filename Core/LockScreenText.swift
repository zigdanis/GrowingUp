import Foundation

/// The Lock Screen reading of one person at one moment: who it is, how old they are and how close their birthday is.
///
/// It is derived from `AgeSummary` and `BirthdayStatus`, so the Lock Screen agrees with the app and the Home Screen
/// widgets. The age never shows minutes or seconds: it counts down to days, or to hours on the day of birth, which
/// reads "0 hours" during the first hour of life. The day of birth itself is not a birthday.
public struct LockScreenText: Equatable, Sendable {
	/// How many days ahead the inline widget announces the birthday instead of the age.
	public static let inlineBirthdayDays = 7
	/// How many days ahead the rectangular widget adds a birthday line.
	public static let birthdayLineDays = 30

	public let name: String
	/// One line for the inline widget: "Leo · 5 years", "Leo's birthday in 3 days" or "Leo turns 6 today".
	public let inline: String
	/// The age in its two largest units, such as "5 years, 3 months".
	public let compactAge: String
	/// "Birthday today 🎂" on the birthday, "Birthday in 12 days" up to `birthdayLineDays` ahead, otherwise `nil`.
	public let birthdayLine: String?
	/// The number of the largest age unit, such as "5".
	public let primaryValue: String
	/// The abbreviated largest age unit in the plural form of `primaryValue`, such as "y" or "мес.".
	public let primaryUnitAbbreviation: String
	/// The part of the year from the previous birthday to the next one that has passed, counted in whole days:
	/// 0 on the day of birth and exactly 1 on the birthday.
	public let yearProgress: Double
	public let isBirthday: Bool
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
		let ageLine = Self.localized("%@ · %@", locale: locale, name, age.primary.localizedString(locale: locale))
		let inline: String
		let birthdayLine: String?
		if isBirthday {
			inline = Self.localized("%@ turns %li today", locale: locale, name, turningAge)
			birthdayLine = Self.localized("Birthday today", locale: locale)
		} else if hasBirthday, (1...Self.birthdayLineDays).contains(status.daysRemaining) {
			let days = status.daysRemaining
			inline = days <= Self.inlineBirthdayDays ? Self.localized("%@'s birthday in %li days", locale: locale, name, days) : ageLine
			birthdayLine = Self.localized("Birthday in %li days", locale: locale, days)
		} else {
			inline = ageLine
			birthdayLine = nil
		}
		let compactAge = age.localizedCompact(locale: locale)
		self.name = name
		self.inline = inline
		self.compactAge = compactAge
		self.birthdayLine = birthdayLine
		primaryValue = age.localizedPrimaryValue(locale: locale)
		primaryUnitAbbreviation = Self.abbreviatedUnit(of: age.primary, locale: locale)
		yearProgress = hasBirthday ? Self.progress(towards: status.date, birthday: birthday, now: now, calendar: calendar) : 0
		self.isBirthday = isBirthday
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

	/// Whole days since the previous birthday over the days between it and `next`.
	private static func progress(towards next: Date, birthday: Date, now: Date, calendar: Calendar) -> Double {
		// The anniversary a year earlier, placed by the same rules as `next`, including February 29.
		let yearBefore = calendar.date(byAdding: .year, value: -1, to: next) ?? next
		let previous = BirthdayStatus(birthday: birthday, now: yearBefore, calendar: calendar).date
		let total = calendar.dateComponents([.day], from: previous, to: next).day ?? 0
		let elapsed = calendar.dateComponents([.day], from: previous, to: calendar.startOfDay(for: now)).day ?? 0
		return total > 0 ? min(1, max(0, Double(elapsed) / Double(total))) : 0
	}

	/// The unit of `value` in Foundation's abbreviated duration style for `locale`, without the number,
	/// the same way `AgeUnitValue.localizedUnit(locale:)` derives the full unit name.
	private static func abbreviatedUnit(of value: AgeUnitValue, locale: Locale) -> String {
		var calendar = Calendar(identifier: .gregorian)
		calendar.locale = locale
		let formatter = DateComponentsFormatter()
		formatter.calendar = calendar
		formatter.unitsStyle = .abbreviated
		formatter.allowedUnits = value.unit.formatterUnit
		// Keeps "0h" during the first hour instead of dropping the only unit.
		formatter.zeroFormattingBehavior = .pad
		var components = DateComponents()
		components.setValue(value.value, for: value.unit.calendarComponent)
		return (formatter.string(from: components) ?? "")
			.replacingOccurrences(of: value.localizedValue(locale: locale), with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
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
