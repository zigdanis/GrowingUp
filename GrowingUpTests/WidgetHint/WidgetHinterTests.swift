import Core
import XCTest

@testable import GrowingUp

/// The session around the widget hint's rules: the widget lookup, launches, setbacks, its end and forced checks.
@MainActor
final class WidgetHinterTests: XCTestCase {
	private let day: TimeInterval = 86_400
	private var now = Date(timeIntervalSince1970: 1_800_000_000)
	/// What the widget lookup answers: true for an installed widget, nil for a failed lookup.
	private var installed: Bool? = false
	private var usage: ReviewPromptState = {
		var state = ReviewPromptState()
		state.activeDays = 2
		state.viewerVisits = 1
		return state
	}()
	/// A new, empty suite for every test.
	private let defaults = UserDefaults(suiteName: "WidgetHinterTests.\(UUID().uuidString)")!
	private let analytics = AnalyticsGatewaySpy()

	func testShowsOnceTheLookupFindsNoWidgetAndCountsTheLaunchOnce() async {
		let hinter = await makeHinter()
		XCTAssertFalse(hinter.offers(people: people()), "Nothing before the mosaic reveals it")
		hinter.reveal(people: people())
		XCTAssertTrue(hinter.offers(people: people()))
		hinter.reveal(people: people())
		XCTAssertEqual(store().state.shownLaunches, 1)
		XCTAssertEqual(analytics.events, [.widgetHintShown(shownLaunches: 1)])
		XCTAssertFalse(hinter.offers(people: [person(onWidget: false)]), "Nobody on the widget any more")
	}

	func testWaitsForTheDaysAndVisitsTheRatingPromptCounts() async {
		usage.activeDays = 1
		let hinter = await makeHinter()
		hinter.reveal(people: people())
		XCTAssertFalse(hinter.offers(people: people()))
		usage.activeDays = 2
		hinter.reveal(people: people())
		XCTAssertTrue(hinter.offers(people: people()))
	}

	func testAnInstalledWidgetEndsTheHintForGoodAndAFailedLookupHidesIt() async {
		installed = nil
		let failed = await makeHinter()
		failed.reveal(people: people())
		XCTAssertFalse(failed.offers(people: people()), "A failed lookup means no hint")
		XCTAssertFalse(store().state.isRetired)
		installed = false
		failed.appBecameActive()
		await failed.waitForWidgetLookup()
		failed.reveal(people: people())
		XCTAssertTrue(failed.offers(people: people()))
		installed = true
		failed.appBecameActive()
		await failed.waitForWidgetLookup()
		XCTAssertFalse(failed.offers(people: people()), "A widget added meanwhile, as the guide explains")
		XCTAssertTrue(store().state.isRetired)
		installed = false
		failed.appBecameActive()
		await failed.waitForWidgetLookup()
		failed.reveal(people: people())
		XCTAssertFalse(failed.offers(people: people()), "Gone for good, even once the widget is removed")
	}

	func testATapOrCloseEndsTheHintForGood() async {
		let opened = await makeHinter()
		opened.reveal(people: people())
		opened.opened()
		XCTAssertFalse(opened.offers(people: people()))
		XCTAssertEqual(analytics.events.last, .widgetHintOpened(shownLaunches: 1))
		XCTAssertTrue(store().state.isRetired)
		let reopened = await makeHinter()
		reopened.reveal(people: people())
		XCTAssertFalse(reopened.offers(people: people()), "Retirement is stored")

		let closedDefaults = UserDefaults(suiteName: "WidgetHinterTests.\(UUID().uuidString)")!
		let closed = await makeHinter(defaults: closedDefaults)
		closed.reveal(people: people())
		closed.dismissed()
		XCTAssertFalse(closed.offers(people: people()))
		XCTAssertEqual(analytics.events.last, .widgetHintDismissed(shownLaunches: 1))
		XCTAssertTrue(WidgetHintStore(defaults: closedDefaults).state.isRetired)
	}

	func testASetbackHidesTheHintForTheSession() async {
		let hinter = await makeHinter()
		hinter.reveal(people: people())
		hinter.noteSetback()
		XCTAssertFalse(hinter.offers(people: people()))
		hinter.reveal(people: people())
		XCTAssertFalse(hinter.offers(people: people()), "Not again in the same session")
		await startNewSession(hinter)
		hinter.reveal(people: people())
		XCTAssertTrue(hinter.offers(people: people()))
		XCTAssertEqual(store().state.shownLaunches, 2)
	}

	func testAHintInPlaceCountsEveryLaunchUntilTheTenth() async {
		let hinter = await makeHinter()
		hinter.reveal(people: people())
		for _ in 0..<9 { await startNewSession(hinter) }
		XCTAssertTrue(hinter.offers(people: people()))
		XCTAssertEqual(store().state.shownLaunches, 10)
		await startNewSession(hinter)
		XCTAssertFalse(hinter.offers(people: people()), "Ten launches without a tap")
		XCTAssertEqual(store().state.shownLaunches, 10)
		XCTAssertEqual(analytics.events.count, 10)
	}

	func testARecentRatingRequestKeepsTheHintAway() async {
		usage.requestDates = [now - 3_600]
		let hinter = await makeHinter()
		hinter.reveal(people: people())
		XCTAssertFalse(hinter.offers(people: people()))
		now += day
		hinter.reveal(people: people())
		XCTAssertTrue(hinter.offers(people: people()))
	}

	func testAForcedCheckShowsAtOnceAndStoresNothing() async {
		usage = ReviewPromptState()
		installed = true
		let hinter = await makeHinter(mode: .forced)
		hinter.reveal(people: people())
		XCTAssertTrue(hinter.offers(people: people()), "Whatever the days, visits and installed widgets")
		hinter.dismissed()
		XCTAssertFalse(hinter.offers(people: people()))
		XCTAssertNil(defaults.data(forKey: WidgetHintStore.key))
	}

	func testOnlyRealUseOrAForcedCheckShowsTheHint() {
		XCTAssertEqual(WidgetHintMode.current(environment: [:]), .policy)
		XCTAssertEqual(WidgetHintMode.current(environment: ["GROWINGUP_WIDGET_HINT": "force"]), .forced)
		XCTAssertNil(WidgetHintMode.current(environment: ["GROWINGUP_UI_TEST_CONFIGURATION": "x"]))
		XCTAssertNil(WidgetHintMode.current(environment: ["XCTestConfigurationFilePath": "x"]))
	}

	func testAnUnreadableStoredValueNeverBringsTheHintBack() {
		defaults.set(Data("not json".utf8), forKey: WidgetHintStore.key)
		XCTAssertTrue(store().state.isRetired)
	}

	// MARK: - Helpers

	private func makeHinter(mode: WidgetHintMode = .policy, defaults: UserDefaults? = nil) async -> WidgetHinter {
		let hinter = WidgetHinter(
			store: WidgetHintStore(defaults: defaults ?? self.defaults), usage: { [unowned self] in self.usage }, mode: mode,
			lookUpWidget: { [unowned self] in self.installed }, analytics: analytics, now: { [unowned self] in self.now },
			calendar: calendar)
		hinter.appBecameActive()
		await hinter.waitForWidgetLookup()
		return hinter
	}

	/// Leaves the app and comes back the next day, after the widget lookup.
	private func startNewSession(_ hinter: WidgetHinter) async {
		hinter.appEnteredBackground()
		now += day
		hinter.appBecameActive()
		await hinter.waitForWidgetLookup()
	}

	private func store() -> WidgetHintStore {
		WidgetHintStore(defaults: defaults)
	}

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}

	private func people() -> [Person] {
		[person(onWidget: true), person(onWidget: false)]
	}

	private func person(onWidget: Bool) -> Person {
		// Born in March, so no birthday falls on the test days in January.
		Person(
			id: UUID(), name: "Mia", birthday: Date(timeIntervalSince1970: 1_710_000_000), appPicId: nil, widgetPicId: nil,
			isOnWidget: onWidget, createdDate: now)
	}
}
