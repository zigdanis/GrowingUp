import Core
import XCTest

final class LockScreenTextTests: XCTestCase {
	private let english = Locale(identifier: "en")
	private let russian = Locale(identifier: "ru")

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	/// Leo was born on 3 June 2020 at 08:00.
	private var leo: Date { date(2020, 6, 3, 8) }

	func testOrdinaryDayShowsTheAgeWithoutBirthdayLine() {
		let lockScreen = text(leo, date(2025, 9, 15, 20, 30))
		XCTAssertEqual(lockScreen.inline, "Leo · 5 years")
		XCTAssertEqual(lockScreen.compactAge, "5 years, 3 months")
		XCTAssertNil(lockScreen.birthdayLine)
		XCTAssertFalse(lockScreen.isBirthday)
		XCTAssertEqual(lockScreen.primaryValue, "5")
		XCTAssertEqual(lockScreen.initial, "L")
		XCTAssertEqual(lockScreen.yearProgress, 104.0 / 365.0, accuracy: 1e-9)
		XCTAssertEqual(lockScreen.accessibilityLabel, "Leo, 5 years, 3 months")
	}

	func testBirthdayLastsTheWholeDayAndFillsTheRing() {
		for now in [date(2026, 6, 3), date(2026, 6, 3, 5), date(2026, 6, 3, 10), date(2026, 6, 3, 23, 59)] {
			let lockScreen = text(leo, now)
			XCTAssertTrue(lockScreen.isBirthday, "\(now)")
			XCTAssertEqual(lockScreen.inline, "Leo turns 6 today", "\(now)")
			XCTAssertEqual(lockScreen.birthdayLine, "Birthday today 🎂", "\(now)")
			XCTAssertEqual(lockScreen.yearProgress, 1, "\(now)")
		}
		// The age itself counts from the birth time, while the celebration starts at midnight.
		XCTAssertEqual(text(leo, date(2026, 6, 3, 5)).compactAge, "5 years, 11 months")
		XCTAssertEqual(text(leo, date(2026, 6, 3, 10)).compactAge, "6 years")
		XCTAssertTrue(text(leo, date(2026, 6, 3, 10)).accessibilityLabel.hasPrefix("Leo, 6 years"))
		let dayAfter = text(leo, date(2026, 6, 4, 12))
		XCTAssertFalse(dayAfter.isBirthday)
		XCTAssertEqual(dayAfter.inline, "Leo · 6 years")
		XCTAssertEqual(dayAfter.yearProgress, 1.0 / 365.0, accuracy: 1e-9)
	}

	func testWeekBeforeTheBirthdayInlineAnnouncesIt() {
		XCTAssertEqual(text(leo, date(2026, 5, 31, 12)).inline, "Leo's birthday in 3 days")
		XCTAssertEqual(text(leo, date(2026, 5, 31, 12)).birthdayLine, "Birthday in 3 days")
		XCTAssertEqual(text(leo, date(2026, 6, 2, 12)).inline, "Leo's birthday in 1 day")
		XCTAssertEqual(text(leo, date(2026, 6, 2, 12)).birthdayLine, "Birthday in 1 day")
		XCTAssertEqual(text(leo, date(2026, 5, 27, 12)).inline, "Leo's birthday in 7 days")
		XCTAssertEqual(text(leo, date(2026, 5, 26, 12)).inline, "Leo · 5 years")
	}

	func testMonthBeforeTheBirthdayOnlyTheRectangularLineAnnouncesIt() {
		let twelveDays = text(leo, date(2026, 5, 22, 12))
		XCTAssertEqual(twelveDays.inline, "Leo · 5 years")
		XCTAssertEqual(twelveDays.birthdayLine, "Birthday in 12 days")
		XCTAssertEqual(twelveDays.accessibilityLabel, "Leo, 5 years, 11 months, Birthday in 12 days")
		XCTAssertEqual(text(leo, date(2026, 5, 4, 12)).birthdayLine, "Birthday in 30 days")
		XCTAssertNil(text(leo, date(2026, 5, 3, 12)).birthdayLine)
		XCTAssertNil(text(leo, date(2026, 1, 3, 12)).birthdayLine)
	}

	func testNewbornCountsHoursAndHasNoBirthdayOnTheDayOfBirth() {
		let birth = date(2026, 1, 10, 10, 7).addingTimeInterval(30)
		let hours = text(birth, date(2026, 1, 10, 15, 20))
		XCTAssertEqual(hours.compactAge, "5 hours")
		XCTAssertEqual(hours.inline, "Leo · 5 hours")
		XCTAssertEqual(hours.primaryValue, "5")
		XCTAssertFalse(hours.isBirthday)
		XCTAssertNil(hours.birthdayLine)
		XCTAssertEqual(hours.yearProgress, 0)
		XCTAssertEqual(text(birth, date(2026, 1, 10, 10, 30)).compactAge, "0 hours")
		let firstDay = text(birth, date(2026, 1, 11, 12))
		XCTAssertEqual(firstDay.compactAge, "1 day")
		XCTAssertEqual(firstDay.yearProgress, 1.0 / 365.0, accuracy: 1e-9)
		let firstBirthday = text(birth, date(2027, 1, 10))
		XCTAssertTrue(firstBirthday.isBirthday)
		XCTAssertEqual(firstBirthday.inline, "Leo turns 1 today")
	}

	func testLeapDayBirthdayIsCelebratedOnFebruary28() {
		let birth = date(2020, 2, 29, 10)
		let commonYear = text(birth, date(2021, 2, 28, 9))
		XCTAssertTrue(commonYear.isBirthday)
		XCTAssertEqual(commonYear.inline, "Leo turns 1 today")
		XCTAssertEqual(commonYear.yearProgress, 1)
		XCTAssertFalse(text(birth, date(2024, 2, 28, 9)).isBirthday)
		XCTAssertEqual(text(birth, date(2024, 2, 29, 9)).inline, "Leo turns 4 today")
		// The year after a February 29 birthday ends on February 28.
		XCTAssertEqual(text(birth, date(2024, 3, 1, 9)).yearProgress, 1.0 / 365.0, accuracy: 1e-9)
		XCTAssertEqual(text(birth, date(2023, 3, 1, 9)).yearProgress, 1.0 / 366.0, accuracy: 1e-9)
	}

	func testRussianDayCountsUseThePluralRules() {
		for (now, days, expected) in [
			(date(2026, 6, 2, 12), "1 день", true), (date(2026, 5, 31, 12), "3 дня", true),
			(date(2026, 5, 29, 12), "5 дней", true), (date(2026, 5, 13, 12), "21 день", false)
		] {
			let lockScreen = text(leo, now, name: "Лео", locale: russian)
			XCTAssertEqual(lockScreen.birthdayLine, "День рождения через \(days)")
			XCTAssertEqual(lockScreen.inline, expected ? "Лео · день рождения через \(days)" : "Лео · 5 лет")
		}
		XCTAssertEqual(text(leo, date(2026, 6, 3, 10), name: "Лео", locale: russian).birthdayLine, "Сегодня день рождения 🎂")
	}

	func testRussianYearsUseThePluralRules() {
		for (years, word) in [(1, "год"), (2, "года"), (5, "лет"), (21, "год")] {
			let birth = date(2026 - years, 3, 1, 8)
			let birthday = text(birth, date(2026, 3, 1, 12), name: "Лео", locale: russian)
			XCTAssertEqual(birthday.inline, "Лео · сегодня исполняется \(years) \(word)")
			let ordinary = text(birth, date(2026, 3, 15, 12), name: "Лео", locale: russian)
			XCTAssertEqual(ordinary.inline, "Лео · \(years) \(word)")
			XCTAssertEqual(ordinary.initial, "Л")
		}
	}

	func testUnitAbbreviationsAreShortFormsOfTheLocalizedUnit() {
		let ages: [(Date, AgeUnit)] = [
			(date(2026, 3, 15, 12), .years), (date(2020, 10, 15, 12), .months), (date(2020, 6, 15, 12), .days),
			(date(2020, 6, 3, 13), .hours)
		]
		for locale in [english, russian] {
			for (now, unit) in ages {
				let lockScreen = text(leo, now, locale: locale)
				let full = AgeSummary(birthday: leo, now: now, finestUnit: unit == .hours ? .hours : .days, calendar: calendar)
				XCTAssertEqual(full.primary.unit, unit)
				let abbreviation = lockScreen.primaryUnitAbbreviation
				XCTAssertFalse(abbreviation.isEmpty, "\(locale.identifier) \(unit)")
				XCTAssertNil(abbreviation.rangeOfCharacter(from: .decimalDigits), abbreviation)
				XCTAssertLessThan(abbreviation.count, full.localizedPrimaryUnit(locale: locale).count, abbreviation)
			}
		}
	}

	private func text(_ birthday: Date, _ now: Date, name: String = "Leo", locale: Locale? = nil) -> LockScreenText {
		LockScreenText(name: name, birthday: birthday, now: now, locale: locale ?? english, calendar: calendar)
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
