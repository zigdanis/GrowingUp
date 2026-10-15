import Foundation

/// A whole number of one age unit, such as "5 years", localized through Foundation's formatters.
public struct AgeUnitValue: Codable, Hashable, Sendable {
	public let value: Int
	public let unit: AgeUnit

	public init(value: Int, unit: AgeUnit) {
		self.value = value
		self.unit = unit
	}

	/// The number alone, such as "5", formatted with the numerals of `locale`.
	public func localizedValue(locale: Locale = .current) -> String {
		value.formatted(.number.locale(locale))
	}

	/// The unit name alone, in the plural form that matches the value, such as "years" or "лет" for 5 and "год" for 21.
	///
	/// Derived from `localizedString(locale:)` by removing the formatted number, so the plural form always
	/// follows Foundation's rules for `locale`.
	public func localizedUnit(locale: Locale = .current) -> String {
		localizedString(locale: locale)
			.replacingOccurrences(of: localizedValue(locale: locale), with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/// The number and its unit, such as "5 years" or "5 лет".
	public func localizedString(locale: Locale = .current) -> String {
		Self.localizedString(for: [self], locale: locale)
	}

	/// Formats `values` as one phrase, such as "5 years, 3 months", with `DateComponentsFormatter`'s full style.
	static func localizedString(for values: [AgeUnitValue], locale: Locale) -> String {
		var calendar = Calendar(identifier: .gregorian)
		calendar.locale = locale
		let formatter = DateComponentsFormatter()
		formatter.calendar = calendar
		formatter.unitsStyle = .full
		// Keeps a zero age readable as "0 minutes" instead of dropping the only unit.
		formatter.zeroFormattingBehavior = .pad
		var components = DateComponents()
		var units: NSCalendar.Unit = []
		for item in values {
			components.setValue(item.value, for: item.unit.calendarComponent)
			units.insert(item.unit.formatterUnit)
		}
		formatter.allowedUnits = units
		return formatter.string(from: components) ?? ""
	}
}
