import Core
import XCTest

@testable import GrowingUp

/// The moment of the rating request on the mosaic: after the viewer closes, and only while nothing covers the mosaic,
/// the app is active and nothing went wrong.
@MainActor
final class PeopleReviewPromptTests: XCTestCase {
	private var now = Date(timeIntervalSince1970: 1_800_000_000)
	/// A new, empty suite for every test.
	private let defaults = UserDefaults(suiteName: "PeopleReviewPromptTests.\(UUID().uuidString)")!

	func testAClosedViewerAsksOnceTheMosaicShowsAgain() async {
		let people = makePeople()
		let (presenter, analytics) = await loadedPresenter(people)
		presenter.view(people[0].id)
		now += 5
		presenter.closeViewer()
		XCTAssertNil(presenter.pendingReviewRequest, "Nothing is asked while the cover still shows")
		presenter.coverDidClose()
		XCTAssertNotNil(presenter.pendingReviewRequest)
		XCTAssertTrue(presenter.takeReviewRequest())
		XCTAssertNil(presenter.pendingReviewRequest)
		XCTAssertEqual(analytics.events.last?.name, "review_prompt_requested")
		XCTAssertEqual(ReviewPromptStore(defaults: defaults).state.requestCount, 1)
		XCTAssertFalse(presenter.takeReviewRequest(), "One request per closed viewer")
	}

	func testARequestWaitsForTheMosaicToBeFreeAndTheAppActive() async {
		let people = makePeople()
		let (presenter, _) = await loadedPresenter(people)
		visit(people[0], in: presenter)
		presenter.view(people[1].id)
		XCTAssertFalse(presenter.takeReviewRequest(), "The viewer opened again during the pause")
		now += 5
		presenter.closeViewer()
		presenter.coverDidClose()
		presenter.sceneDidResignActive()
		XCTAssertFalse(presenter.takeReviewRequest(), "Control Center or a notification is over the app")
		presenter.sceneDidBecomeActive()
		visit(people[1], in: presenter)
		presenter.add()
		XCTAssertFalse(presenter.takeReviewRequest(), "A new person's page opened during the pause")
		XCTAssertEqual(ReviewPromptStore(defaults: defaults).state.requestCount, 0)
	}

	func testAFailureOrARemovalKeepsTheRequestAway() async {
		let people = makePeople(count: 3)
		let (presenter, _) = await loadedPresenter(people)
		visit(people[0], in: presenter)
		// An editor reports its failures through the same gateway, while the request waits.
		presenter.configurator.analytics.report(AnalyticsFailure(operation: "save_person", error: CoreError.coreDataSaveFailed))
		XCTAssertFalse(presenter.takeReviewRequest())
		presenter.sceneDidEnterBackground()
		presenter.sceneDidBecomeActive()
		presenter.view(people[2].id)
		presenter.edit(people[2])
		now += 5
		presenter.apply(.removed(people[2]), from: presenter.editor)
		presenter.coverDidClose()
		XCTAssertNil(presenter.pendingReviewRequest, "A removal is no moment to ask")
	}

	func testANewPersonsPageIsNoVisit() async {
		let (presenter, _) = await loadedPresenter(makePeople())
		presenter.add()
		now += 30
		var added = Person.createPerson()
		added.createdDate = now
		presenter.apply(.saved(added), from: presenter.editor)
		presenter.coverDidClose()
		XCTAssertNil(presenter.pendingReviewRequest)
		XCTAssertEqual(ReviewPromptStore(defaults: defaults).state.viewerVisits, 4)
	}

	func testWithoutAPrompterTheAppNeverAsks() async {
		let people = makePeople()
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		presenter.sceneDidBecomeActive()
		presenter.view(people[0].id)
		presenter.closeViewer()
		presenter.coverDidClose()
		XCTAssertNil(presenter.pendingReviewRequest)
	}

	/// Shows `person` for five seconds and returns to the mosaic, which starts a request.
	private func visit(_ person: Person, in presenter: PeoplePresenter) {
		presenter.view(person.id)
		now += 5
		presenter.closeViewer()
		presenter.coverDidClose()
		XCTAssertNotNil(presenter.pendingReviewRequest)
	}

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}

	/// A week after the first of three days of use, with four visits behind: the next visit is the fifth.
	private func seedReadyState() {
		var state = ReviewPromptState()
		state.activeDays = 3
		state.lastActiveDay = ReviewPromptPolicy.dayKey(for: now, calendar: calendar)
		state.firstActiveDate = now.addingTimeInterval(-7 * 86_400)
		state.viewerVisits = 4
		ReviewPromptStore(defaults: defaults).state = state
	}

	private func loadedPresenter(_ people: [Person]) async -> (PeoplePresenter, AnalyticsGatewaySpy) {
		seedReadyState()
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		gateway.removePersonResultToBeReturned = .success(())
		let analytics = AnalyticsGatewaySpy()
		let prompter = ReviewPrompter(
			store: ReviewPromptStore(defaults: defaults), version: "3.1", now: { [unowned self] in self.now }, calendar: calendar)
		let presenter = PeoplePresenter(
			configurator: SceneConfigurator(gateway: gateway, analytics: analytics, reviewPrompter: prompter), reloadWidgets: {})
		await presenter.load()
		presenter.sceneDidBecomeActive()
		return (presenter, analytics)
	}

	private func makePeople(count: Int = 2) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
	}
}
