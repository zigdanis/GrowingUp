import Foundation

/// Birthday celebrations start at local midnight, independently of the birth time.
public struct BirthdayStatus: Equatable, Sendable {
	public let date: Date
	public let isToday: Bool
	public let daysRemaining: Int
	public let countdown: DateComponents

	public var isUpcoming: Bool { isToday || (0...14).contains(daysRemaining) }

	public init(birthday: Date, now: Date, calendar: Calendar = .current) {
		let today = calendar.startOfDay(for: now)
		let birth = calendar.dateComponents([.month, .day], from: birthday)
		let year = calendar.component(.year, from: today)
		let anniversary = Self.anniversary(year: year, birth: birth, calendar: calendar)
		date = anniversary >= today ? anniversary : Self.anniversary(year: year + 1, birth: birth, calendar: calendar)
		isToday = calendar.isDate(date, inSameDayAs: today)
		daysRemaining = calendar.dateComponents([.day], from: today, to: date).day ?? 0
		let seconds = max(0, date.timeIntervalSince(now))
		var remaining = DateComponents()
		if seconds >= 86_400 {
			remaining.day = daysRemaining
		} else if seconds >= 3_600 {
			remaining.hour = Int(ceil(seconds / 3_600))
		} else if seconds >= 60 {
			remaining.minute = Int(ceil(seconds / 60))
		} else {
			remaining.second = Int(ceil(seconds))
		}
		countdown = remaining
	}

	private static func anniversary(year: Int, birth: DateComponents, calendar: Calendar) -> Date {
		let first = calendar.date(from: DateComponents(year: year, month: birth.month, day: 1))!
		let lastDay = calendar.range(of: .day, in: .month, for: first)!.count
		// February 29 is celebrated on February 28 in non-leap years.
		let day = min(birth.day ?? 1, lastDay)
		return calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: birth.month, day: day))!)
	}
}
