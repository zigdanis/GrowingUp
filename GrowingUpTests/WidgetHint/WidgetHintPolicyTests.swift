import Core
import XCTest

@testable import GrowingUp

/// The pure rules of the Home Screen widget hint: days of use, visits, launches, rating requests and the people.
final class WidgetHintPolicyTests: XCTestCase {
	private let policy = WidgetHintPolicy()
	private let now = Date(timeIntervalSince1970: 1_800_000_000)
	private let day: TimeInterval = 86_400
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}

	func testShowsFromTheSecondDayOfUseAfterAVisitToTheViewer() {
		XCTAssertTrue(policy.allowsLaunch(WidgetHintState(), usage: usage(), now: now))
		XCTAssertFalse(policy.allowsLaunch(WidgetHintState(), usage: usage(activeDays: 1), now: now), "A second day of use")
		XCTAssertFalse(policy.allowsLaunch(WidgetHintState(), usage: usage(viewerVisits: 0), now: now), "A visit to the viewer")
	}

	func testEndsAfterRetirementOrTenLaunches() {
		XCTAssertFalse(policy.allowsLaunch(policy.retiring(WidgetHintState()), usage: usage(), now: now))
		var state = WidgetHintState()
		for _ in 0..<9 { state = policy.recordingShownLaunch(state) }
		XCTAssertTrue(policy.allowsLaunch(state, usage: usage(), now: now), "Shown on nine launches: a tenth is allowed")
		state = policy.recordingShownLaunch(state)
		XCTAssertEqual(state.shownLaunches, 10)
		XCTAssertFalse(policy.allowsLaunch(state, usage: usage(), now: now), "Ten launches without a tap")
	}

	func testStaysAwayForADayAfterARatingRequest() {
		XCTAssertFalse(policy.allowsLaunch(WidgetHintState(), usage: usage(lastRequest: now - day + 60), now: now))
		XCTAssertTrue(policy.allowsLaunch(WidgetHintState(), usage: usage(lastRequest: now - day), now: now))
		XCTAssertFalse(policy.allowsLaunch(WidgetHintState(), usage: usage(lastRequest: now + 3_600), now: now), "A request dated ahead")
	}

	func testNeedsSomeoneOnTheWidgetAndNoCelebratedBirthdayToday() {
		let pinned = person(onWidget: true)
		XCTAssertTrue(policy.allowsPeople([pinned], now: now, calendar: calendar))
		XCTAssertFalse(policy.allowsPeople([person(onWidget: false)], now: now, calendar: calendar), "Someone on the widget")
		XCTAssertFalse(policy.allowsPeople([], now: now, calendar: calendar))
		let birthday = person(onWidget: false, birthday: calendar.date(byAdding: .year, value: -3, to: now))
		XCTAssertTrue(BirthdayStatus(birthday: birthday.birthday, now: now, calendar: calendar).isToday)
		XCTAssertFalse(policy.allowsPeople([pinned, birthday], now: now, calendar: calendar), "A birthday celebration today")
		var quiet = birthday
		quiet.celebratesBirthdays = false
		XCTAssertTrue(policy.allowsPeople([pinned, quiet], now: now, calendar: calendar), "A birthday the app doesn't celebrate")
	}

	func testAStoredStateFromAnotherVersionKeepsTheHintRetired() throws {
		let decoded = try JSONDecoder().decode(WidgetHintState.self, from: Data(#"{"isRetired":true,"future":1}"#.utf8))
		XCTAssertEqual(decoded, WidgetHintState(isRetired: true, shownLaunches: 0))
		XCTAssertEqual(try JSONDecoder().decode(WidgetHintState.self, from: Data("{}".utf8)), WidgetHintState())
	}

	private func usage(activeDays: Int = 2, viewerVisits: Int = 1, lastRequest: Date? = nil) -> ReviewPromptState {
		var state = ReviewPromptState()
		state.activeDays = activeDays
		state.viewerVisits = viewerVisits
		state.requestDates = lastRequest.map { [$0] } ?? []
		return state
	}

	private func person(onWidget: Bool, birthday: Date? = nil) -> Person {
		Person(
			id: UUID(), name: "Mia", birthday: birthday ?? now - 100 * day, appPicId: nil, widgetPicId: nil, isOnWidget: onWidget,
			createdDate: now)
	}
}
