import Core
import XCTest

@testable import GrowingUp

/// The widget hint on the mosaic: it takes its place as the people load, keeps it while reordering hides it, and keeps
/// the rating request away while it is there.
@MainActor
final class PeopleWidgetHintTests: XCTestCase {
	private var now = Date(timeIntervalSince1970: 1_800_000_000)
	/// A new, empty suite for every test.
	private let defaults = UserDefaults(suiteName: "PeopleWidgetHintTests.\(UUID().uuidString)")!

	func testTheHintIsInPlaceWhenThePeopleFirstShow() async {
		let (presenter, analytics) = await loadedPresenter()
		XCTAssertTrue(presenter.showsWidgetHint)
		XCTAssertEqual(analytics.events.last, .widgetHintShown(shownLaunches: 1))
	}

	func testReorderingHidesTheHintButKeepsItsPlace() async {
		let (presenter, _) = await loadedPresenter()
		presenter.startReordering()
		XCTAssertFalse(presenter.showsWidgetHint)
		XCTAssertTrue(presenter.reservesWidgetHint, "No tile moves as the hint hides")
		presenter.dismissWidgetHint()
		XCTAssertFalse(WidgetHintStore(defaults: defaults).state.isRetired, "A hidden hint can't be closed")
		presenter.finishReordering()
		XCTAssertTrue(presenter.showsWidgetHint)
	}

	func testATapOpensTheGuideOnceAndEndsTheHint() async {
		let (presenter, analytics) = await loadedPresenter()
		XCTAssertTrue(presenter.openWidgetHint())
		XCTAssertFalse(presenter.showsWidgetHint)
		XCTAssertFalse(presenter.openWidgetHint())
		XCTAssertEqual(analytics.events.last, .widgetHintOpened(shownLaunches: 1))
	}

	func testAnAlertTakesTheHintAway() async {
		let (presenter, _) = await loadedPresenter()
		presenter.error = SceneError(CoreError.coreDataSaveFailed)
		presenter.error = nil
		XCTAssertFalse(presenter.reservesWidgetHint)
	}

	func testNoRatingRequestWhileTheHintIsThere() async throws {
		let (presenter, _) = await loadedPresenter()
		let prompter = try XCTUnwrap(presenter.configurator.reviewPrompter)
		presenter.view(presenter.persons[0].id)
		now += 5
		presenter.closeViewer()
		presenter.coverDidClose()
		let request = try XCTUnwrap(prompter.pendingRequest)
		XCTAssertFalse(presenter.takeReviewRequest(request))
	}

	func testThePreviewShowsThePinnedPeople() async {
		let (presenter, _) = await loadedPresenter()
		let entry = await presenter.widgetPreviewEntry()
		XCTAssertEqual(entry.persons.map(\.id), presenter.persons.filter(\.isOnWidget).map(\.id))
	}

	private func loadedPresenter() async -> (PeoplePresenter, AnalyticsGatewaySpy) {
		// Ready for both the hint and the rating request, which the hint must hold back.
		var usage = ReviewPromptState()
		usage.activeDays = 3
		usage.lastActiveDay = ReviewPromptPolicy.dayKey(for: now, calendar: calendar)
		usage.firstActiveDate = now.addingTimeInterval(-7 * 86_400)
		usage.viewerVisits = 4
		let reviewStore = ReviewPromptStore(defaults: defaults)
		reviewStore.state = usage
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(makePeople())
		let analytics = AnalyticsGatewaySpy()
		let prompter = ReviewPrompter(store: reviewStore, version: "3.1", now: { [unowned self] in self.now }, calendar: calendar)
		let hinter = WidgetHinter(
			store: WidgetHintStore(defaults: defaults), usage: { reviewStore.state }, lookUpWidget: { false }, analytics: analytics,
			now: { [unowned self] in self.now }, calendar: calendar)
		await hinter.waitForWidgetLookup()
		let presenter = PeoplePresenter(
			configurator: SceneConfigurator(gateway: gateway, analytics: analytics, reviewPrompter: prompter, widgetHinter: hinter),
			reloadWidgets: {})
		await presenter.loadWithWidgetHint()
		prompter.appBecameActive()
		return (presenter, analytics)
	}

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}

	private func makePeople() -> [Person] {
		(0..<2).map { index in
			Person(
				id: UUID(), name: "Person \(index)", birthday: Date(timeIntervalSince1970: 1_710_000_000), appPicId: UUID(), widgetPicId: nil,
				isOnWidget: index == 0, createdDate: Date(timeIntervalSince1970: Double(index)))
		}
	}
}
