import Core
import XCTest

final class AgeSummaryTests: XCTestCase {
	private let english = Locale(identifier: "en")
	private let russian = Locale(identifier: "ru")

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		return calendar
	}

	/// 10 January 2026 at 10:07:30.
	private var newborn: Date { date(2026, 1, 10, 10, 7).addingTimeInterval(30) }

	func testNewbornLeadsWithTheLargestNonZeroUnit() {
		let hours = summary(newborn, date(2026, 1, 10, 13, 20).addingTimeInterval(45))
		XCTAssertEqual(hours.primary, AgeUnitValue(value: 3, unit: .hours))
		XCTAssertEqual(hours.secondary, AgeUnitValue(value: 13, unit: .minutes))
		let minutes = summary(newborn, date(2026, 1, 10, 10, 52).addingTimeInterval(40))
		XCTAssertEqual(minutes.primary, AgeUnitValue(value: 45, unit: .minutes))
		XCTAssertEqual(minutes.secondary, AgeUnitValue(value: 10, unit: .seconds))
		let zero = summary(newborn, newborn, .minutes)
		XCTAssertEqual(zero.primary, AgeUnitValue(value: 0, unit: .minutes))
		XCTAssertNil(zero.secondary)
		XCTAssertEqual(zero.localizedCompact(locale: english), "0 minutes")
		XCTAssertEqual(summary(newborn, date(2025, 12, 31), .minutes), zero, "A future birthday reads as a zero age")
	}

	func testDaysMonthsAndYearsAreFollowedByTheNextFinerUnit() {
		let days = summary(newborn, date(2026, 1, 12, 15))
		XCTAssertEqual(days.primary, AgeUnitValue(value: 2, unit: .days))
		XCTAssertEqual(days.secondary, AgeUnitValue(value: 4, unit: .hours))
		XCTAssertEqual(days.localizedCompact(locale: english), "2 days, 4 hours")
		let months = summary(date(2025, 2, 10, 10), date(2026, 1, 25, 12))
		XCTAssertEqual(months.primary, AgeUnitValue(value: 11, unit: .months))
		XCTAssertEqual(months.secondary, AgeUnitValue(value: 15, unit: .days))
		XCTAssertEqual(months.localizedCompact(locale: english), "11 months, 15 days")
		let years = summary(date(2020, 6, 3, 8), date(2025, 9, 15, 20, 30), .minutes)
		XCTAssertEqual(years.primary, AgeUnitValue(value: 5, unit: .years))
		XCTAssertEqual(years.secondary, AgeUnitValue(value: 3, unit: .months))
		XCTAssertEqual(years.localizedPrimaryValue(locale: english), "5")
		XCTAssertEqual(years.localizedPrimaryUnit(locale: english), "years")
		XCTAssertEqual(years.localizedSecondary(locale: english), "3 months")
		XCTAssertEqual(years.localizedCompact(locale: english), "5 years, 3 months")
		XCTAssertEqual(years.localizedPrimaryUnit(locale: russian), "лет")
		XCTAssertEqual(years.localizedSecondary(locale: russian), "3 месяца")
		let russianCompact = years.localizedCompact(locale: russian)
		XCTAssertTrue(russianCompact.hasPrefix("5 лет"), russianCompact)
		XCTAssertTrue(russianCompact.hasSuffix("3 месяца"), russianCompact)
	}

	func testSecondaryIsAtMostTwoUnitsFinerAndNeverBelowTheFinestUnit() {
		let birthday = date(2025, 1, 10, 10, 7).addingTimeInterval(30)
		let exact = summary(birthday, date(2026, 1, 10, 10, 7).addingTimeInterval(30))
		XCTAssertEqual(exact.primary, AgeUnitValue(value: 1, unit: .years))
		XCTAssertNil(exact.secondary)
		XCTAssertEqual(exact.localizedCompact(locale: english), "1 year")
		XCTAssertEqual(exact.localizedCompact(locale: russian), "1 год")
		let fiveDays = summary(birthday, date(2026, 1, 15, 12))
		XCTAssertEqual(fiveDays.secondary, AgeUnitValue(value: 5, unit: .days))
		XCTAssertEqual(fiveDays.localizedCompact(locale: english), "1 year, 5 days")
		let adult = date(2020, 6, 3, 8)
		let sixYearsFiveHours = summary(adult, date(2026, 6, 3, 13), .minutes)
		XCTAssertEqual(sixYearsFiveHours.primary, AgeUnitValue(value: 6, unit: .years))
		XCTAssertNil(sixYearsFiveHours.secondary)
		XCTAssertEqual(sixYearsFiveHours.localizedCompact(locale: english), "6 years")
		XCTAssertEqual(summary(adult, date(2026, 6, 4, 13), .minutes).localizedCompact(locale: english), "6 years, 1 day")
		XCTAssertEqual(summary(adult, date(2020, 9, 3, 13), .minutes).localizedCompact(locale: english), "3 months, 5 hours")
		let fiveDaysOld = summary(adult, date(2020, 6, 8, 8, 30))
		XCTAssertEqual(fiveDaysOld.secondary, AgeUnitValue(value: 30, unit: .minutes))
		XCTAssertNil(summary(adult, date(2020, 6, 8, 8, 30), .hours).secondary)
	}

	func testFinestUnitTruncatesInsteadOfRounding() {
		let almostTwoMinutes = date(2026, 1, 10, 10, 9).addingTimeInterval(29)
		XCTAssertEqual(summary(newborn, almostTwoMinutes).secondary, AgeUnitValue(value: 59, unit: .seconds))
		XCTAssertEqual(summary(newborn, almostTwoMinutes, .minutes).primary, AgeUnitValue(value: 1, unit: .minutes))
		XCTAssertNil(summary(newborn, almostTwoMinutes, .minutes).secondary)
		let halfMinute = date(2026, 1, 10, 10, 7).addingTimeInterval(59)
		XCTAssertEqual(summary(newborn, halfMinute, .minutes).primary, AgeUnitValue(value: 0, unit: .minutes))
		let oneHour = date(2026, 1, 10, 11, 8)
		XCTAssertEqual(summary(newborn, oneHour).secondary, AgeUnitValue(value: 30, unit: .seconds))
		XCTAssertEqual(summary(newborn, oneHour, .minutes).primary, AgeUnitValue(value: 1, unit: .hours))
		XCTAssertNil(summary(newborn, oneHour, .minutes).secondary)
	}

	func testLeapDayBirthdayCountsLikeTheCalendar() {
		let birthday = date(2020, 2, 29, 10)
		let leapYear = summary(birthday, date(2024, 2, 29, 10))
		XCTAssertEqual(leapYear.primary, AgeUnitValue(value: 4, unit: .years))
		XCTAssertNil(leapYear.secondary)
		XCTAssertEqual(summary(birthday, date(2021, 3, 1, 10), .days).primary, AgeUnitValue(value: 1, unit: .years))
		for now in [date(2021, 2, 28, 12), date(2021, 3, 1, 9), date(2021, 3, 15, 12)] {
			let years = calendar.dateComponents([.year], from: birthday, to: now).year ?? 0
			let age = summary(birthday, now, .days)
			XCTAssertEqual(age.primary.unit == .years ? age.primary.value : 0, years)
		}
	}

	func testUnitNamesFollowThePluralRulesOfTheLocale() {
		let russianYears = [(1, "год"), (2, "года"), (5, "лет"), (11, "лет"), (21, "год")]
		let englishYears = [(1, "year"), (2, "years"), (5, "years"), (11, "years"), (21, "years")]
		for (locale, words) in [(russian, russianYears), (english, englishYears)] {
			for (count, word) in words {
				let age = summary(date(2026 - count, 3, 1), date(2026, 3, 1))
				XCTAssertEqual(age.localizedPrimaryValue(locale: locale), "\(count)")
				XCTAssertEqual(age.localizedPrimaryUnit(locale: locale), word)
				XCTAssertEqual(age.localizedCompact(locale: locale), "\(count) \(word)")
			}
		}
		let russianUnits: [(AgeUnit, [String])] = [
			(.months, ["месяц", "месяца", "месяцев", "месяцев", "месяц"]),
			(.days, ["день", "дня", "дней", "дней", "день"]),
			(.hours, ["час", "часа", "часов", "часов", "час"]),
			(.minutes, ["минута", "минуты", "минут", "минут", "минута"])
		]
		for (unit, words) in russianUnits {
			for (count, word) in zip([1, 2, 5, 11, 21], words) {
				let value = AgeUnitValue(value: count, unit: unit)
				XCTAssertEqual(value.localizedUnit(locale: russian), word)
				XCTAssertEqual(value.localizedString(locale: russian), "\(count) \(word)")
			}
		}
	}

	func testNextChangeIsTheNextCountOfTheLastShownUnit() {
		XCTAssertEqual(nextChange(newborn, date(2026, 1, 10, 11, 30), .minutes), date(2026, 1, 10, 11, 30).addingTimeInterval(30))
		XCTAssertEqual(nextChange(newborn, date(2026, 1, 12, 15), .days), date(2026, 1, 13, 10, 7).addingTimeInterval(30))
		XCTAssertEqual(nextChange(date(2020, 6, 3, 8), date(2025, 9, 15, 20, 30), .days), date(2025, 10, 3, 8))
		XCTAssertEqual(nextChange(date(2025, 1, 10, 10, 7), date(2026, 1, 10, 10, 7), .minutes), date(2026, 1, 11, 10, 7))
		XCTAssertEqual(nextChange(date(2020, 6, 3, 8), date(2026, 6, 3, 13), .minutes), date(2026, 6, 4, 8), "6 years waits for a day")
		XCTAssertEqual(nextChange(newborn, date(2026, 1, 10, 11, 8), .minutes), date(2026, 1, 10, 11, 8).addingTimeInterval(30))
		XCTAssertEqual(nextChange(newborn, date(2025, 12, 31), .minutes), date(2026, 1, 10, 10, 8).addingTimeInterval(30))
	}

	func testSummaryHoldsUntilTheNextChangeAndDiffersThere() {
		let nows = [
			newborn, newborn.addingTimeInterval(29), date(2026, 1, 10, 10, 52).addingTimeInterval(40), date(2026, 1, 10, 11, 30),
			date(2026, 1, 12, 15), date(2026, 1, 12, 10, 8), date(2026, 3, 5, 18), date(2027, 1, 10, 10, 7).addingTimeInterval(30),
			date(2027, 1, 10, 11, 7).addingTimeInterval(30), date(2025, 12, 31)
		]
		let leapNows = [date(2021, 2, 28, 12), date(2021, 3, 15, 12), date(2024, 2, 29, 10)]
		let adultNows = [date(2025, 9, 15, 20, 30), date(2026, 6, 3, 13), date(2026, 6, 4, 13), date(2026, 6, 3, 8)]
		for finestUnit in [AgeUnit.seconds, .minutes, .days] {
			for now in nows {
				assertNextChange(newborn, now, finestUnit)
			}
			for now in leapNows {
				assertNextChange(date(2020, 2, 29, 10), now, finestUnit)
			}
			for now in adultNows {
				assertNextChange(date(2020, 6, 3, 8), now, finestUnit)
			}
		}
	}

	func testNextChangeSkipsTheRepeatedHourWhenClocksGoBack() throws {
		var newYork = calendar
		newYork.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
		let birthday = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 10, day: 31)))
		// 06:00 UTC is the second 01:00 of 1 November in New York, where the calendar still counts 1 day, 1 hour.
		let now = date(2026, 11, 1, 6)
		let current = AgeSummary(birthday: birthday, now: now, finestUnit: .minutes, calendar: newYork)
		let next = AgeSummary.nextChangeDate(birthday: birthday, after: now, finestUnit: .minutes, calendar: newYork)
		XCTAssertGreaterThan(next.timeIntervalSince(now), 2)
		XCTAssertNotEqual(AgeSummary(birthday: birthday, now: next, finestUnit: .minutes, calendar: newYork), current)
	}

	private func assertNextChange(_ birthday: Date, _ now: Date, _ finestUnit: AgeUnit, line: UInt = #line) {
		let next = nextChange(birthday, now, finestUnit)
		let current = summary(birthday, now, finestUnit)
		let message = "\(now) at \(finestUnit) changes at \(next)"
		XCTAssertGreaterThan(next, now, message, line: line)
		XCTAssertEqual(summary(birthday, next.addingTimeInterval(-1), finestUnit), current, message, line: line)
		XCTAssertNotEqual(summary(birthday, next, finestUnit), current, message, line: line)
	}

	private func summary(_ birthday: Date, _ now: Date, _ finestUnit: AgeUnit = .seconds) -> AgeSummary {
		AgeSummary(birthday: birthday, now: now, finestUnit: finestUnit, calendar: calendar)
	}

	private func nextChange(_ birthday: Date, _ now: Date, _ finestUnit: AgeUnit) -> Date {
		AgeSummary.nextChangeDate(birthday: birthday, after: now, finestUnit: finestUnit, calendar: calendar)
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
