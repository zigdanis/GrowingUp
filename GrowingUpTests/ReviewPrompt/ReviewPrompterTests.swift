import Core
import XCTest

@testable import GrowingUp

/// The session around the rating rules: visits to the viewer, setbacks, the stored state and verification launches.
@MainActor
final class ReviewPrompterTests: XCTestCase {
	private let day: TimeInterval = 86_400
	private var now = Date(timeIntervalSince1970: 1_800_000_000)
	/// A new, empty suite for every test.
	private let defaults = UserDefaults(suiteName: "ReviewPrompterTests.\(UUID().uuidString)")!

	func testAsksOnTheFirstVisitThatMeetsTheRulesAndOncePerSession() {
		let prompter = makePrompter()
		useOnSeparateDays(prompter, visitsPerDay: 2)
		XCTAssertTrue(visit(prompter))
		let event = prompter.recordRequest(people: people())
		XCTAssertEqual(
			event,
			.reviewPromptRequested(activeDays: 3, daysSinceFirstActive: 7, viewerVisits: 7, peopleWithPhotoCount: 2, requestNumber: 1))
		XCTAssertFalse(visit(prompter), "Once per session")
		prompter.appEnteredBackground()
		now += 200 * day
		prompter.appBecameActive()
		XCTAssertFalse(visit(prompter), "Once per version")
	}

	func testAShortVisitIsNotCounted() {
		let prompter = makePrompter()
		useOnSeparateDays(prompter, visitsPerDay: 2)
		prompter.viewerOpened()
		now += 1
		XCTAssertFalse(prompter.viewerClosed(people: people()))
		XCTAssertEqual(store().state.viewerVisits, 6)
		XCTAssertFalse(prompter.viewerClosed(people: people()), "A close without an open is no visit")
	}

	func testASetbackKeepsTheRequestAwayForTheRestOfTheSession() {
		let prompter = makePrompter()
		useOnSeparateDays(prompter, visitsPerDay: 2)
		prompter.noteSetback()
		XCTAssertFalse(visit(prompter))
		XCTAssertEqual(store().state.viewerVisits, 7, "The visit still counts")
		prompter.appEnteredBackground()
		prompter.appBecameActive()
		XCTAssertTrue(visit(prompter), "A new session starts clean")
	}

	func testASessionPastMidnightCountsTheNewDay() {
		let prompter = makePrompter()
		prompter.appBecameActive()
		now += day
		prompter.appBecameActive()
		now += 6 * day
		XCTAssertEqual(store().state.activeDays, 2)
		prompter.viewerOpened()
		now += 5
		_ = prompter.viewerClosed(people: people())
		XCTAssertEqual(store().state.activeDays, 3)
	}

	func testTimeAwayFromTheAppIsNoTimeInTheViewer() {
		let prompter = makePrompter()
		prompter.viewerOpened()
		now += 1
		prompter.appEnteredBackground()
		now += 60
		prompter.appBecameActive()
		now += 1
		XCTAssertFalse(prompter.viewerClosed(people: people()))
		XCTAssertEqual(store().state.viewerVisits, 0)
	}

	func testANewPersonsPageIsNoVisit() {
		let prompter = makePrompter()
		prompter.viewerOpened()
		prompter.viewerLeftForNewPerson()
		now += 10
		XCTAssertFalse(prompter.viewerClosed(people: people()))
		XCTAssertEqual(store().state.viewerVisits, 0)
	}

	func testAForcedCheckAsksOnEveryVisitAndStoresNothing() {
		let prompter = makePrompter(mode: .forced)
		XCTAssertTrue(visit(prompter))
		_ = prompter.recordRequest(people: people())
		XCTAssertTrue(visit(prompter))
		XCTAssertEqual(store().state, ReviewPromptState(), "Nothing a forced check counts reaches the store")
		prompter.noteSetback()
		XCTAssertFalse(visit(prompter), "Setbacks still keep it away")
	}

	func testTheStateSurvivesARelaunchAndUnreadableDataStartsOver() {
		var state = ReviewPromptState()
		state.activeDays = 4
		state.requestDates = [now]
		store().state = state
		XCTAssertEqual(store().state, state)
		defaults.set(Data("not json".utf8), forKey: ReviewPromptStore.key)
		XCTAssertEqual(store().state, ReviewPromptState())
	}

	func testVerificationLaunchesNeverAskUnlessForced() {
		XCTAssertEqual(ReviewPromptMode.current(environment: [:]), .policy)
		XCTAssertNil(ReviewPromptMode.current(environment: ["GROWINGUP_UI_TEST": "{}"]))
		XCTAssertNil(ReviewPromptMode.current(environment: ["XCTestConfigurationFilePath": "/tmp"]))
		XCTAssertNil(ReviewPromptMode.current(environment: ["GROWINGUP_REVIEW_PROMPT": "ready"]))
		XCTAssertEqual(ReviewPromptMode.current(environment: ["GROWINGUP_REVIEW_PROMPT": "force"]), .forced)
	}

	/// Opens the viewer, shows someone for five seconds and closes it.
	private func visit(_ prompter: ReviewPrompter) -> Bool {
		prompter.viewerOpened()
		now += 5
		return prompter.viewerClosed(people: people())
	}

	/// Uses the app on days 1, 2 and 8, with a few visits each day, ending on the morning of day 8.
	private func useOnSeparateDays(_ prompter: ReviewPrompter, visitsPerDay: Int) {
		for offset in [0, 1, 7] {
			now = Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * day)
			prompter.appBecameActive()
			if offset < 7 {
				for _ in 0..<visitsPerDay { _ = visit(prompter) }
				prompter.appEnteredBackground()
			}
		}
		for _ in 0..<visitsPerDay { _ = visit(prompter) }
	}

	private func makePrompter(mode: ReviewPromptMode = .policy) -> ReviewPrompter {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return ReviewPrompter(store: store(), mode: mode, version: "3.1", now: { [unowned self] in self.now }, calendar: calendar)
	}

	private func store() -> ReviewPromptStore {
		ReviewPromptStore(defaults: defaults)
	}

	private func people() -> [Person] {
		[Person.createPerson(), Person.createPerson()]
	}
}
