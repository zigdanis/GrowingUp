import Foundation

/// A milestone-first reading of an age, such as "5 years, 3 months", "11 months, 15 days" or "2 days, 4 hours".
///
/// The app and the widgets build their age text from this one model so they never disagree. It is derived from
/// `AgeCalculator.ageComponents(from:to:calendar:)`, so it counts exactly like the full age breakdown.
public struct AgeSummary: Codable, Hashable, Sendable {
	/// The largest non-zero unit, never finer than `finestUnit`; zero `finestUnit`s for a zero age.
	public let primary: AgeUnitValue
	/// The first non-zero unit among the two units finer than `primary`, never finer than `finestUnit`; `nil` when both are zero.
	///
	/// A zero unit in between is skipped, so 1 year, 0 months and 5 days reads "1 year, 5 days", while 6 years, 0 months,
	/// 0 days and 5 hours reads "6 years": an hour count next to years would read as a glitch rather than as context.
	public let secondary: AgeUnitValue?
	/// The finest unit the summary may show. Finer components are truncated, never rounded, so a summary with
	/// `.minutes` never runs ahead of the clock.
	public let finestUnit: AgeUnit

	/// Summarizes the age from `birthday` up to `now`; a birthday after `now` reads as a zero age.
	public init(birthday: Date, now: Date, finestUnit: AgeUnit = .seconds, calendar: Calendar = .current) {
		let values = Self.ageValues(birthday: birthday, now: now, calendar: calendar).filter { $0.unit >= finestUnit }
		let primaryIndex = values.firstIndex { $0.value > 0 } ?? values.count - 1
		primary = values[primaryIndex]
		secondary = values.dropFirst(primaryIndex + 1).prefix(Self.secondaryReach).first { $0.value > 0 }
		self.finestUnit = finestUnit
	}

	/// How many units finer than `primary` the secondary unit may be.
	private static let secondaryReach = 2

	/// The finest unit `secondary` may use.
	private var finestSecondaryUnit: AgeUnit {
		max(finestUnit, AgeUnit(rawValue: primary.unit.rawValue - Self.secondaryReach) ?? .seconds)
	}

	/// The primary number alone, such as "5".
	public func localizedPrimaryValue(locale: Locale = .current) -> String {
		primary.localizedValue(locale: locale)
	}

	/// The primary unit name alone, in the plural form that matches the primary number, such as "years" or "лет".
	public func localizedPrimaryUnit(locale: Locale = .current) -> String {
		primary.localizedUnit(locale: locale)
	}

	/// The secondary number with its unit, such as "3 months", or `nil` without a secondary unit.
	public func localizedSecondary(locale: Locale = .current) -> String? {
		secondary?.localizedString(locale: locale)
	}

	/// The primary and secondary values as one phrase in the list style of `locale`, such as "5 years, 3 months".
	public func localizedCompact(locale: Locale = .current) -> String {
		AgeUnitValue.localizedString(for: [primary, secondary].compactMap { $0 }, locale: locale)
	}

	/// The earliest instant strictly after `now` at which `AgeSummary(birthday:now:finestUnit:calendar:)` reads differently.
	///
	/// A summary only changes when the last unit it shows counts up: `secondary`, or the finest unit a secondary could
	/// use while there is none. "5 years, 3 months" therefore changes on the next monthly anniversary of the birth time,
	/// and "6 years" on the next day at the birth time, which lets a widget timeline add entries only when its text changes.
	public static func nextChangeDate(birthday: Date, after now: Date, finestUnit: AgeUnit = .seconds, calendar: Calendar = .current) -> Date {
		let summary = AgeSummary(birthday: birthday, now: now, finestUnit: finestUnit, calendar: calendar)
		let changingUnit = summary.secondary?.unit ?? summary.finestSecondaryUnit
		let fields = Set(AgeUnit.allCases.map(\.calendarComponent))
		var anniversary = calendar.date(from: calendar.dateComponents(fields, from: birthday)) ?? birthday
		var next = Date.distantFuture
		// Replays the calendar's difference: every unit counts on from the anniversary reached by the coarser units,
		// so the earliest next count among the shown units is the next change.
		for item in ageValues(birthday: birthday, now: now, calendar: calendar) where item.unit >= changingUnit {
			let component = item.unit.calendarComponent
			next = min(next, calendar.date(byAdding: component, value: item.value + 1, to: anniversary) ?? next)
			anniversary = calendar.date(byAdding: component, value: item.value, to: anniversary) ?? anniversary
		}
		return next > now ? next : now.addingTimeInterval(1)
	}

	/// Whole units of age from `birthday` up to `now`, coarsest first, as counted by `AgeCalculator`; zero before the birthday.
	private static func ageValues(birthday: Date, now: Date, calendar: Calendar) -> [AgeUnitValue] {
		let components = AgeCalculator.ageComponents(from: birthday, to: max(birthday, now), calendar: calendar)
		return AgeUnit.allCases.reversed().map { unit in
			AgeUnitValue(value: max(0, components.value(for: unit.calendarComponent) ?? 0), unit: unit)
		}
	}
}
