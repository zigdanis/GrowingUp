import Core
import XCTest

@testable import GrowingUp

/// The pure rules of the App Store rating request: days of use, visits, people, and how often it may ask.
final class ReviewPromptPolicyTests: XCTestCase {
	private let policy = ReviewPromptPolicy()
	private let start = Date(timeIntervalSince1970: 1_800_000_000)
	private let day: TimeInterval = 86_400
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}

	func testADayOfUseCountsOnceHoweverOftenTheAppOpens() {
		var state = policy.recordingActiveDay(ReviewPromptState(), now: start, calendar: calendar)
		state = policy.recordingActiveDay(state, now: start.addingTimeInterval(3_600), calendar: calendar)
		XCTAssertEqual(state.activeDays, 1)
		XCTAssertEqual(state.firstActiveDate, start)
		state = policy.recordingActiveDay(state, now: start.addingTimeInterval(day), calendar: calendar)
		state = policy.recordingActiveDay(state, now: start.addingTimeInterval(9 * day), calendar: calendar)
		XCTAssertEqual(state.activeDays, 3, "Days of use need not follow each other")
		XCTAssertEqual(state.firstActiveDate, start, "The first day stays the first")
		XCTAssertEqual(policy.daysSinceFirstActive(state, now: start.addingTimeInterval(9 * day), calendar: calendar), 9)
	}

	func testOnlyAViewerShownForAFewSecondsIsAVisit() {
		XCTAssertFalse(policy.isVisit(from: start, to: start.addingTimeInterval(2.9)))
		XCTAssertTrue(policy.isVisit(from: start, to: start.addingTimeInterval(3)))
	}

	func testAsksOnTheThirdDayOfUseAWeekInWithFiveVisitsAndTwoPeopleWithAPhoto() {
		let now = start.addingTimeInterval(7 * day)
		XCTAssertTrue(ask(readyState(), now: now))
		var fewDays = readyState()
		fewDays.activeDays = 2
		XCTAssertFalse(ask(fewDays, now: now), "Third day of use")
		XCTAssertFalse(ask(readyState(), now: start.addingTimeInterval(6 * day)), "A week after the first day")
		var fewVisits = readyState()
		fewVisits.viewerVisits = 4
		XCTAssertFalse(ask(fewVisits, now: now), "Five visits to the viewer")
		XCTAssertFalse(ask(readyState(), now: now, people: [person(withPhoto: true)]), "Two people")
		XCTAssertFalse(
			ask(readyState(), now: now, people: [person(withPhoto: false), person(withPhoto: false)]), "At least one photo")
		XCTAssertTrue(ask(readyState(), now: now, people: [person(withPhoto: true), person(withPhoto: false)]))
	}

	func testAsksOncePerVersionAtLeast120DaysApartAfterThreeNewDaysOfUse() {
		let asked = start.addingTimeInterval(7 * day)
		var state = policy.recordingRequest(readyState(), now: asked, version: "3.1")
		XCTAssertEqual(state.requestCount, 1)
		XCTAssertEqual(state.activeDaysAtLastRequest, 3)
		state.activeDays = 10
		let later = asked.addingTimeInterval(200 * day)
		XCTAssertFalse(ask(state, now: later, version: "3.1"), "Once per version")
		XCTAssertTrue(ask(state, now: later, version: "3.2"))
		XCTAssertFalse(ask(state, now: asked.addingTimeInterval(119 * day), version: "3.2"), "120 days apart")
		state.activeDays = 5
		XCTAssertFalse(ask(state, now: later, version: "3.2"), "Three new days of use since the last request")
	}

	func testAsksAtMostThreeTimesInAYear() {
		var state = readyState()
		state.activeDays = 30
		state.requestDates = [start, start.addingTimeInterval(120 * day), start.addingTimeInterval(240 * day)]
		state.lastRequestVersion = "3.2"
		let now = start.addingTimeInterval(362 * day)
		XCTAssertFalse(ask(state, now: now, version: "3.3"))
		XCTAssertTrue(ask(state, now: start.addingTimeInterval(366 * day), version: "3.3"), "The oldest request left the year")
		let recorded = policy.recordingRequest(state, now: start.addingTimeInterval(366 * day), version: "3.3")
		XCTAssertEqual(recorded.requestDates.count, 3, "Requests older than a year are dropped")
	}

	private func ask(_ state: ReviewPromptState, now: Date, version: String = "3.1", people: [Person]? = nil) -> Bool {
		policy.shouldRequest(
			state, now: now, calendar: calendar, version: version,
			people: people ?? [person(withPhoto: true), person(withPhoto: true)])
	}

	private func readyState() -> ReviewPromptState {
		var state = ReviewPromptState()
		state.activeDays = 3
		state.firstActiveDate = start
		state.viewerVisits = 5
		return state
	}

	private func person(withPhoto: Bool) -> Person {
		var person = Person.createPerson()
		if !withPhoto {
			person.appPicId = nil
			person.widgetPicId = nil
		}
		return person
	}
}
