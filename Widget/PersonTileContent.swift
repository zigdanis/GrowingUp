import Core
import Foundation

/// The text one person's widget tile shows at a timeline entry's date.
struct PersonTileContent {
	/// Widgets refresh once a minute at most, so their summaries never show seconds.
	static let finestUnit = AgeUnit.minutes

	let name: String
	/// The primary number, such as "5".
	let value: String
	/// The primary unit in the plural form that matches `value`, such as "years".
	let unit: String
	/// A birthday caption when the birthday is today or within a week, otherwise the secondary unit, such as "and 3 months".
	let caption: String?
	let isBirthday: Bool
	/// The name, the compact age and any birthday caption, starting with the name so UI tests can find the tile.
	let accessibilityLabel: String

	init(person: WidgetPerson, date: Date, locale: Locale, calendar: Calendar = .current) {
		let summary = AgeSummary(birthday: person.birthday, now: date, finestUnit: Self.finestUnit, calendar: calendar)
		let birthday = BirthdayStatus(birthday: person.birthday, now: date, calendar: calendar)
		let birthdayCaption = Self.birthdayCaption(for: birthday, locale: locale)
		name = person.name
		value = summary.localizedPrimaryValue(locale: locale)
		unit = summary.localizedPrimaryUnit(locale: locale)
		let secondaryCaption = summary.localizedSecondary(locale: locale).map { String(localized: "and \($0)", table: "Widget") }
		caption = birthdayCaption ?? secondaryCaption
		isBirthday = birthday.isToday
		accessibilityLabel = [person.name, summary.localizedCompact(locale: locale), birthdayCaption].compactMap { $0 }.joined(separator: ", ")
	}

	private static func birthdayCaption(for birthday: BirthdayStatus, locale: Locale) -> String? {
		if birthday.isToday {
			return String(localized: "Birthday today", table: "Widget")
		}
		guard (1...7).contains(birthday.daysRemaining) else { return nil }
		let days = AgeUnitValue(value: birthday.daysRemaining, unit: .days).localizedString(locale: locale)
		return String(localized: "Birthday in \(days)", table: "Widget")
	}
}
