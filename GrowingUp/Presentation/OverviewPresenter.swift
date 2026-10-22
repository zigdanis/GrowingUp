import Core
import Observation
import UIKit

@MainActor
@Observable
final class OverviewPresenter {
	private(set) var image: UIImage?
	/// The milestone age shown in large type; minutes are its finest unit, so only `tickerText` changes every second.
	private(set) var summary: AgeSummary?
	/// "and 3 months" under the milestone, or "Turns 6 years old today 🎂" on a birthday; `nil` without a second unit.
	private(set) var secondaryText: String?
	/// The exact remainder, such as "12 days · 04:07:33".
	private(set) var tickerText = ""
	/// The next birthday, such as "Birthday in 14 days".
	private(set) var birthdayText = ""
	/// The age and next birthday as one spoken phrase, such as "5 years and 3 months, Birthday in 12 days".
	private(set) var accessibilityAge = ""
	private(set) var birthdayStatus: BirthdayStatus?
	private(set) var celebrationID = 0
	private var wasCelebrating = false
	var error: SceneError?
	private let loadImage: (PersonImage) async throws -> UIImage
	private let calendar: Calendar
	private let locale: Locale

	init(
		loadImage: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadImageFromDiskOrMemory, calendar: Calendar = .autoupdatingCurrent,
		locale: Locale = .autoupdatingCurrent
	) {
		self.loadImage = loadImage
		self.calendar = calendar
		self.locale = locale
	}

	var primaryValue: String { summary?.localizedPrimaryValue(locale: locale) ?? "" }
	var primaryUnit: String { summary?.localizedPrimaryUnit(locale: locale) ?? "" }

	func load(person: Person) async {
		image = nil
		guard let picture = PersonImage(id: person.appPicId) else { return }
		do {
			let loaded = try await loadImage(picture)
			try Task.checkCancellation()
			image = loaded
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
		}
	}

	func tick(person: Person, now: Date, isSelected: Bool = false) {
		let status = BirthdayStatus(birthday: person.birthday, now: now, calendar: calendar)
		// A visible birthday starts a new celebration on every page arrival, at midnight, and when the person's
		// celebrations are turned back on. People who opted out keep the indicator but get no confetti.
		let isCelebrating = isSelected && status.isToday && person.celebratesBirthdays
		if isCelebrating, !wasCelebrating {
			celebrationID += 1
		}
		wasCelebrating = isCelebrating
		birthdayStatus = status
		updateAge(person: person, now: now)
	}

	/// Derives the milestone age, its ticker and the next-birthday line in the presenter's calendar and locale.
	private func updateAge(person: Person, now: Date) {
		let status = BirthdayStatus(birthday: person.birthday, now: now, calendar: calendar)
		let summary = AgeSummary(birthday: person.birthday, now: now, finestUnit: .minutes, calendar: calendar)
		self.summary = summary
		tickerText = AgeTicker.text(birthday: person.birthday, now: now, summary: summary, calendar: calendar, locale: locale)
		birthdayText = BirthdayCountdown.text(for: status, locale: locale)
		let age = summary.primary.localizedString(locale: locale)
		// The day someone is born is not a birthday they turn an age on.
		let turning = calendar.component(.year, from: status.date) - calendar.component(.year, from: person.birthday)
		if status.isToday, turning > 0 {
			let years = AgeUnitValue(value: turning, unit: .years).localizedString(locale: locale)
			let turns = String(localized: "Turns \(years) today 🎂", locale: locale)
			secondaryText = turns
			accessibilityAge = "\(age), \(turns)"
		} else {
			let secondary = summary.localizedSecondary(locale: locale).map { String(localized: "and \($0)", locale: locale) }
			secondaryText = secondary
			accessibilityAge = [age, secondary].compactMap { $0 }.joined(separator: " ") + ", \(birthdayText)"
		}
	}
}
