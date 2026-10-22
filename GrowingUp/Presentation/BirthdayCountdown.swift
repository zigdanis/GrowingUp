import Core
import Foundation

/// The next-birthday line of the person page, such as "Birthday in 14 days" or "Birthday today 🎂".
///
/// The remaining time uses the single unit chosen by `BirthdayStatus.countdown`, so it switches from days to hours,
/// minutes and seconds as the celebration approaches.
enum BirthdayCountdown {
	static func text(for status: BirthdayStatus, locale: Locale = .current) -> String {
		let bundle = localizedBundle(for: locale)
		guard !status.isToday else { return String(localized: "Birthday today 🎂", bundle: bundle, locale: locale) }
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
		return String(localized: "Birthday in \(duration)", bundle: bundle, locale: locale)
	}

	/// `String(localized:locale:)` uses the locale for formatting, but the bundle chooses the language.
	/// Match Core's `LockScreenText` lookup so an explicit locale also controls the surrounding phrase.
	private static func localizedBundle(for locale: Locale) -> Bundle {
		let bundle = Bundle.main
		let language = locale.language.languageCode?.identifier ?? ""
		let localization = bundle.localizations.contains(language) ? language : bundle.developmentLocalization
		return localization.flatMap { bundle.path(forResource: $0, ofType: "lproj") }.flatMap(Bundle.init(path:)) ?? bundle
	}
}
