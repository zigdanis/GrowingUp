import Foundation

/// The moments at which `LockScreenText` reads differently for one person, so a widget timeline adds entries only there.
public enum LockScreenSchedule {
	/// The sorted, distinct moments strictly after `now`, at most `limit` of them, merging two sources:
	///
	/// - every change of the age as the Lock Screen counts it, from `AgeSummary.nextChangeDate`: hourly during the first
	///   day of life, then never finer than a day;
	/// - every local midnight, when the birthday countdown and the ring move on. Birthdays start at midnight, so the
	///   next birthday is among them once it is within reach.
	///
	/// A midnight and an age change can be less than an hour apart when someone was born just after midnight.
	public static func entryDates(birthday: Date, after now: Date, calendar: Calendar = .current, limit: Int) -> [Date] {
		guard limit > 0 else { return [] }
		var dates = Set<Date>()
		var change = now
		var midnight = now
		// Each source alone yields `limit` moments, so the earliest `limit` of their union are all here.
		for _ in 0..<limit {
			let finestUnit = LockScreenText.finestUnit(birthday: birthday, now: change, calendar: calendar)
			change = AgeSummary.nextChangeDate(birthday: birthday, after: change, finestUnit: finestUnit, calendar: calendar)
			midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: midnight)) ?? midnight)
			dates.formUnion([change, midnight])
		}
		return Array(dates.filter { $0 > now }.sorted().prefix(limit))
	}
}
