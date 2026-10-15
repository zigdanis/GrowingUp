import Core
import Foundation

/// The live line under a milestone age, such as "12 days · 04:07:33", counting what the summary leaves out.
///
/// Days appear only while the summary shows nothing finer than months; the clock of the remaining hours,
/// minutes and seconds always follows, so the line keeps its shape while it ticks every second.
enum AgeTicker {
	static func text(birthday: Date, now: Date, summary: AgeSummary, calendar: Calendar = .current, locale: Locale = .current) -> String {
		let age = AgeCalculator.ageComponents(from: birthday, to: max(birthday, now), calendar: calendar)
		let seconds = (age.hour ?? 0) * 3_600 + (age.minute ?? 0) * 60 + (age.second ?? 0)
		let clock = Duration.seconds(max(0, seconds)).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2)).locale(locale))
		let finestShown = summary.secondary?.unit ?? summary.primary.unit
		guard finestShown > .days else { return clock }
		let days = AgeUnitValue(value: max(0, age.day ?? 0), unit: .days).localizedString(locale: locale)
		return "\(days) · \(clock)"
	}
}
