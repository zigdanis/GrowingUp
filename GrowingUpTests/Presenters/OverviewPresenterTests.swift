import Core
import XCTest

@testable import GrowingUp

@MainActor
final class OverviewPresenterTests: XCTestCase {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	func testChildLeadsWithYearsThenMonthsAndTheExactRemainder() {
		let presenter = makePresenter()
		presenter.tick(person: person(born: date(2020, 6, 3, 8)), now: date(2025, 9, 15, 12, 7, 33))
		XCTAssertEqual(presenter.primaryValue, "5")
		XCTAssertEqual(presenter.primaryUnit, "years")
		XCTAssertEqual(presenter.secondaryText, "and 3 months")
		XCTAssertEqual(presenter.tickerText, "12 days · 04:07:33")
		XCTAssertEqual(presenter.birthdayText, "Birthday in 261 days")
		XCTAssertEqual(presenter.accessibilityAge, "5 years and 3 months, Birthday in 261 days")
	}

	func testOnlyTheTickerChangesFromSecondToSecond() {
		let presenter = makePresenter()
		let child = person(born: date(2020, 6, 3, 8))
		presenter.tick(person: child, now: date(2025, 9, 15, 12, 7, 33))
		let summary = presenter.summary
		presenter.tick(person: child, now: date(2025, 9, 15, 12, 7, 34))
		XCTAssertEqual(presenter.summary, summary)
		XCTAssertEqual(presenter.secondaryText, "and 3 months")
		XCTAssertEqual(presenter.tickerText, "12 days · 04:07:34")
		// Seconds never become the secondary unit, even for a newborn of a few minutes.
		let newborn = person(born: date(2026, 1, 10, 10, 7, 30))
		presenter.tick(person: newborn, now: date(2026, 1, 10, 10, 52, 10))
		let minutes = presenter.summary
		presenter.tick(person: newborn, now: date(2026, 1, 10, 10, 52, 11))
		XCTAssertEqual(presenter.summary, minutes)
		XCTAssertNil(presenter.secondaryText)
		XCTAssertEqual(presenter.tickerText, "00:44:41")
	}

	func testNewbornCountsInDaysHoursAndMinutes() {
		let presenter = makePresenter()
		let newborn = person(born: date(2026, 1, 10, 10, 7, 30))
		presenter.tick(person: newborn, now: date(2026, 1, 12, 14, 20, 45))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit, presenter.secondaryText], ["2", "days", "and 4 hours"])
		XCTAssertEqual(presenter.tickerText, "04:13:15")
		XCTAssertEqual(presenter.birthdayText, "Birthday in 363 days")
		presenter.tick(person: newborn, now: date(2026, 1, 10, 13, 20, 45))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit, presenter.secondaryText], ["3", "hours", "and 13 minutes"])
		XCTAssertEqual(presenter.tickerText, "03:13:15")
		// The day of birth is not a birthday someone turns an age on.
		XCTAssertEqual(presenter.birthdayText, "Birthday today 🎂")
		XCTAssertEqual(presenter.accessibilityAge, "3 hours and 13 minutes, Birthday today 🎂")
		presenter.tick(person: newborn, now: date(2026, 1, 10, 10, 7, 30))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit], ["0", "minutes"])
		XCTAssertNil(presenter.secondaryText)
		XCTAssertEqual(presenter.tickerText, "00:00:00")
	}

	func testBirthdayAnnouncesTheAgeBeingTurnedAllDay() {
		let presenter = makePresenter()
		let child = person(born: date(2020, 1, 16, 6, 30))
		// Before the birth time the age still reads 6 years.
		presenter.tick(person: child, now: date(2027, 1, 16, 3))
		XCTAssertEqual([presenter.primaryValue, presenter.primaryUnit], ["6", "years"])
		XCTAssertEqual(presenter.secondaryText, "Turns 7 years old today 🎂")
		XCTAssertEqual(presenter.tickerText, "30 days · 20:30:00")
		XCTAssertEqual(presenter.birthdayText, "Birthday today 🎂")
		XCTAssertEqual(presenter.accessibilityAge, "6 years, Turns 7 years old today 🎂")
		presenter.tick(person: child, now: date(2027, 1, 16, 8))
		XCTAssertEqual(presenter.primaryValue, "7")
		XCTAssertEqual(presenter.secondaryText, "Turns 7 years old today 🎂")
		XCTAssertEqual(presenter.tickerText, "0 days · 01:30:00")
		presenter.tick(person: person(born: date(2026, 1, 16, 6, 30)), now: date(2027, 1, 16, 8))
		XCTAssertEqual(presenter.secondaryText, "Turns 1 year old today 🎂")
		// Hours are too fine to follow years, so the ticker carries them.
		presenter.tick(person: child, now: date(2027, 1, 17))
		XCTAssertNil(presenter.secondaryText)
		XCTAssertEqual(presenter.tickerText, "0 days · 17:30:00")
		XCTAssertEqual(presenter.birthdayText, "Birthday in 364 days")
	}

	func testBirthdayLineSwitchesUnitsAsMidnightApproaches() {
		let child = person(born: date(2020, 1, 16, 6))
		let midnight = date(2027, 1, 16)
		for (identifier, prefix, today, durations) in [
			(
				"en", "Birthday in ", "Birthday today 🎂",
				["15 days", "14 days", "1 day", "24 hours", "1 hour", "60 minutes", "1 minute", "59 seconds", "30 seconds", "1 second"]
			),
			(
				"ru", "До дня рождения: ", "Сегодня день рождения 🎂",
				["15 дней", "14 дней", "1 день", "24 часа", "1 час", "60 минут", "1 минута", "59 секунд", "30 секунд", "1 секунда"]
			)
		] {
			let presenter = OverviewPresenter(calendar: calendar, locale: Locale(identifier: identifier))
			let remaining: [TimeInterval] = [86_400 * 15, 86_400 * 14, 86_400, 86_399, 3_600, 3_599, 60, 59, 30, 1]
			for (seconds, duration) in zip(remaining, durations) {
				presenter.tick(person: child, now: midnight.addingTimeInterval(-seconds))
				XCTAssertEqual(presenter.birthdayText, prefix + duration, "\(identifier): \(seconds) seconds remaining")
				XCTAssertEqual(presenter.birthdayStatus?.isUpcoming, seconds <= 86_400 * 14)
			}
			presenter.tick(person: child, now: midnight)
			XCTAssertEqual(presenter.birthdayText, today)
		}
	}

	func testClockAdvancesFromLiveSecondsThroughMidnightAndRepeatedArrivals() {
		let presenter = makePresenter()
		let child = person(born: date(2020, 1, 16, 6))
		var now = date(2027, 1, 15, 23, 59, 30)
		let clock = { now }
		presenter.tick(person: child, now: clock(), isSelected: true)
		XCTAssertEqual(presenter.birthdayText, "Birthday in 30 seconds")
		XCTAssertEqual(presenter.celebrationID, 0)
		now = now.addingTimeInterval(1)
		presenter.tick(person: child, now: clock(), isSelected: true)
		XCTAssertEqual(presenter.birthdayText, "Birthday in 29 seconds")
		now = now.addingTimeInterval(29)
		presenter.tick(person: child, now: clock(), isSelected: true)
		XCTAssertEqual(presenter.birthdayText, "Birthday today 🎂")
		XCTAssertEqual(presenter.celebrationID, 1)
		for arrival in 2...3 {
			now = now.addingTimeInterval(60)
			presenter.tick(person: child, now: clock(), isSelected: true)
			XCTAssertEqual(presenter.celebrationID, arrival - 1, "Timer ticks must not restart the burst")
			presenter.tick(person: child, now: clock(), isSelected: false)
			presenter.tick(person: child, now: clock(), isSelected: true)
			XCTAssertEqual(presenter.celebrationID, arrival)
		}
	}

	func testSavedBirthdayMutationUsesTheUpdatedPersonOnEveryClockTick() async {
		let gateway = PersonsGatewaySpy()
		let local = Calendar.current
		var child = person(born: local.date(from: DateComponents(year: 2020, month: 1, day: 16, hour: 6))!)
		child.isOnWidget = false
		gateway.fetchPersonsResultToBeReturned = .success([child])
		var now = local.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 8))!
		let clock = { now }
		let people = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway, now: clock), reloadWidgets: {})
		await people.load()
		people.edit(child)
		let editor = people.editor!
		await editor.load()
		editor.dayOfBirth = local.date(from: DateComponents(year: 2020, month: 1, day: 15))!
		var updated = child
		updated.birthday = editor.birthday
		gateway.editPersonResultToBeReturned = .success(updated)
		await editor.save()
		XCTAssertTrue(gateway.editPersonCalled)
		XCTAssertEqual(gateway.addPersonParameters.combinedDate(), updated.birthday)
		XCTAssertNil(people.editor)
		let presenter = OverviewPresenter(calendar: local, locale: Locale(identifier: "en"))
		for _ in 0..<3 {
			presenter.tick(person: people.persons[0], now: clock(), isSelected: true)
			XCTAssertEqual(presenter.birthdayText, "Birthday today 🎂")
			XCTAssertEqual(presenter.celebrationID, 1)
			now = now.addingTimeInterval(60)
		}
	}

	private func makePresenter() -> OverviewPresenter {
		OverviewPresenter(loadImage: { _ in UIImage() }, calendar: calendar, locale: Locale(identifier: "en"))
	}

	private func person(born birthday: Date) -> Person {
		var person = Person.createPerson()
		person.birthday = birthday
		return person
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
	}
}
