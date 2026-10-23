import Core
import XCTest

@testable import GrowingUp

/// A birthday entered in one time zone reads the same day, time, age and next birthday after the device travels.
@MainActor
final class BirthdayTravelTests: XCTestCase {
	private let systemTimeZone = NSTimeZone.default
	private let gateway = CoreDataPersonsGateway(coreDataStack: InMemoryCoreDataStack())

	override func tearDown() async throws {
		NSTimeZone.default = systemTimeZone
		try await super.tearDown()
	}

	func testDateOnlyBirthdayKeepsItsDayAndUnknownTimeAfterTravellingWestAndEast() async throws {
		try await enter(2020, 5, 10)
		for zone in ["America/New_York", "Asia/Tokyo"] {
			travel(to: zone)
			let person = try await storedPerson()
			let editor = editor(for: person)
			XCTAssertEqual(reading(editor.birthday), [2020, 5, 10, 0, 0], zone)
			XCTAssertFalse(editor.hasBirthTime, zone)
			let overview = overview(of: person)
			XCTAssertEqual(overview.accessibilityAge, "6 years and 5 months, Birthday in 199 days", zone)
			XCTAssertEqual(overview.tickerText, "13 days · 12:00:00", zone)
		}
	}

	func testBirthTimeNearMidnightKeepsItsDayAndTimeAfterTravellingWestAndEast() async throws {
		try await enter(2020, 5, 10, hour: 23, minute: 50)
		for zone in ["America/New_York", "Asia/Tokyo"] {
			travel(to: zone)
			let person = try await storedPerson()
			let editor = editor(for: person)
			XCTAssertEqual(reading(editor.birthday), [2020, 5, 10, 23, 50], zone)
			XCTAssertTrue(editor.hasBirthTime, zone)
			let overview = overview(of: person)
			XCTAssertEqual(overview.accessibilityAge, "6 years and 5 months, Birthday in 199 days", zone)
			XCTAssertEqual(overview.tickerText, "12 days · 12:10:00", zone)
		}
	}

	func testFebruary29StaysOnItsDayAfterTravellingWest() async throws {
		try await enter(2020, 2, 29)
		travel(to: "America/New_York")
		let person = try await storedPerson()
		XCTAssertEqual(reading(person.birthday), [2020, 2, 29, 0, 0])
		XCTAssertFalse(editor(for: person).hasBirthTime)
		XCTAssertEqual(reading(BirthdayStatus(birthday: person.birthday, now: date(2027, 2, 1)).date), [2027, 2, 28, 0, 0])
		XCTAssertEqual(reading(BirthdayStatus(birthday: person.birthday, now: date(2028, 2, 1)).date), [2028, 2, 29, 0, 0])
	}

	func testDayStartingAfterMidnightStaysADateOnlyBirthday() async throws {
		// Chile moved its clocks from 00:00 to 01:00 on 6 September 2020, so that day started at 01:00.
		try await enter(2020, 9, 6, in: "America/Santiago")
		let person = try await storedPerson()
		XCTAssertEqual(reading(person.birthday), [2020, 9, 6, 1, 0])
		XCTAssertFalse(editor(for: person).hasBirthTime)
		travel(to: "Europe/Moscow")
		XCTAssertEqual(reading(person.birthday), [2020, 9, 6, 0, 0])
		XCTAssertFalse(editor(for: person).hasBirthTime)
	}

	func testSavingAfterTravelKeepsTheStoredBirthday() async throws {
		let entered = try await enter(2020, 5, 10)
		travel(to: "America/New_York")
		let editor = editor(for: try await storedPerson())
		await editor.load()
		editor.name = "Ada Lovelace"
		await editor.save()
		let saved = try await storedPerson()
		XCTAssertEqual(saved.name, "Ada Lovelace")
		XCTAssertEqual(saved.floatingBirthdate, entered.floatingBirthdate)
	}

	/// Enters and saves a new person through the editor in `zone`, with a birth time only when `hour` is given.
	@discardableResult
	private func enter(
		_ year: Int, _ month: Int, _ day: Int, hour: Int? = nil, minute: Int = 0, in zone: String = "Europe/Moscow"
	) async throws -> Person {
		travel(to: zone)
		let editor = editor(for: nil)
		await editor.load()
		editor.name = "Ada"
		editor.dayOfBirth = date(year, month, day)
		if let hour { editor.timeOfBirth = date(year, month, day, hour, minute) }
		await editor.save()
		XCTAssertNil(editor.error)
		return try await storedPerson()
	}

	private func storedPerson() async throws -> Person {
		try XCTUnwrap(try await gateway.fetchPersons().first)
	}

	private func editor(for person: Person?) -> PersonEditorPresenter {
		SceneConfigurator(gateway: gateway, loadImage: { _ in UIImage() }, now: { self.date(2026, 10, 23, 12) })
			.editor(person: person, onMutation: { _ in })
	}

	/// The person page at local noon on 23 October 2026.
	private func overview(of person: Person) -> OverviewPresenter {
		let overview = OverviewPresenter(loadImage: { _ in UIImage() }, calendar: .current, locale: Locale(identifier: "en"))
		overview.tick(person: person, now: date(2026, 10, 23, 12))
		return overview
	}

	private func travel(to zone: String) {
		NSTimeZone.default = TimeZone(identifier: zone)!
	}

	/// Year, month, day, hour and minute on the local clock.
	private func reading(_ date: Date) -> [Int] {
		let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
		return [components.year, components.month, components.day, components.hour, components.minute].map { $0 ?? -1 }
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
		Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}
}
