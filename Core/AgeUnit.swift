import Foundation

/// A calendar unit an age is counted in, ordered from the finest to the coarsest, so `<` reads "finer than".
public enum AgeUnit: Int, CaseIterable, Comparable, Codable, Hashable, Sendable {
	case seconds
	case minutes
	case hours
	case days
	case months
	case years

	/// The `Calendar` component that counts this unit.
	public var calendarComponent: Calendar.Component {
		switch self {
		case .seconds: .second
		case .minutes: .minute
		case .hours: .hour
		case .days: .day
		case .months: .month
		case .years: .year
		}
	}

	/// The `DateComponentsFormatter` unit that prints this unit.
	var formatterUnit: NSCalendar.Unit {
		switch self {
		case .seconds: .second
		case .minutes: .minute
		case .hours: .hour
		case .days: .day
		case .months: .month
		case .years: .year
		}
	}

	public static func < (lhs: AgeUnit, rhs: AgeUnit) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}
