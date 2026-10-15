import Foundation

/// When the age summaries of several people, and the birthday captions next to them, can change.
///
/// A widget timeline built from these instants refreshes exactly when its text changes: every minute for a newborn,
/// and only at local midnight and on monthly anniversaries for an adult.
public struct AgeTimelineSchedule: Sendable {
	/// The birthdays whose summaries are shown.
	public let birthdays: [Date]
	/// The finest unit the shown summaries use.
	public let finestUnit: AgeUnit
	public let calendar: Calendar

	public init(birthdays: [Date], finestUnit: AgeUnit = .minutes, calendar: Calendar = .current) {
		self.birthdays = birthdays
		self.finestUnit = finestUnit
		self.calendar = calendar
	}

	/// The earliest instant after `date` at which any summary changes or a new calendar day starts.
	///
	/// Local midnight is always included because birthday captions follow calendar days rather than birth times.
	public func nextChange(after date: Date) -> Date {
		let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86_400)
		return birthdays.reduce(midnight) { earliest, birthday in
			min(earliest, AgeSummary.nextChangeDate(birthday: birthday, after: date, finestUnit: finestUnit, calendar: calendar))
		}
	}

	/// Timeline entry dates: `now`, then every following change, stopping after `limit` dates or `horizon` seconds after `now`.
	public func entryDates(from now: Date, limit: Int = 60, horizon: TimeInterval = 86_400) -> [Date] {
		let end = now.addingTimeInterval(horizon)
		var dates = [now]
		var current = now
		while dates.count < limit {
			let next = nextChange(after: current)
			guard next <= end else { break }
			dates.append(next)
			current = next
		}
		return dates
	}
}
