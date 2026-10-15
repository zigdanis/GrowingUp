import Core
import Foundation

/// The next-birthday line of the person page, such as "Birthday in 14 days" or "Birthday today 🎂".
///
/// The remaining time uses the single unit chosen by `BirthdayStatus.countdown`, so it switches from days to hours,
/// minutes and seconds as the celebration approaches.
enum BirthdayCountdown {
	static func text(for status: BirthdayStatus, locale: Locale = .current) -> String {
		guard !status.isToday else { return String(localized: "Birthday today 🎂", locale: locale) }
		let countdown = status.countdown
		let remaining: AgeUnitValue
		if let days = countdown.day {
			remaining = AgeUnitValue(value: days, unit: .days)
		} else if let hours = countdown.hour {
			remaining = AgeUnitValue(value: hours, unit: .hours)
		} else if let minutes = countdown.minute {
			remaining = AgeUnitValue(value: minutes, unit: .minutes)
		} else {
			remaining = AgeUnitValue(value: countdown.second ?? 0, unit: .seconds)
		}
		let duration = remaining.localizedString(locale: locale)
		return String(localized: "Birthday in \(duration)", locale: locale)
	}
}
