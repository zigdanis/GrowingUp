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

	func testAClosedViewerAsksOnceTheMosaicShowsAgain() async throws {
		let people = makePeople()
		let (presenter, analytics) = await loadedPresenter(people)
		let prompter = try XCTUnwrap(presenter.configurator.reviewPrompter)
		presenter.view(people[0].id)
		now += 5
		presenter.closeViewer()
		XCTAssertNil(prompter.pendingRequest, "Nothing is asked while the cover still shows")
		presenter.coverDidClose()
		let request = try XCTUnwrap(prompter.pendingRequest)
		XCTAssertTrue(presenter.takeReviewRequest(request))
		XCTAssertNil(prompter.pendingRequest)
		XCTAssertEqual(analytics.events.last?.name, "review_prompt_requested")
		XCTAssertEqual(ReviewPromptStore(defaults: defaults).state.requestCount, 1)
		XCTAssertFalse(presenter.takeReviewRequest(request), "One request per closed viewer")
	}

	func testARequestWaitsForTheMosaicToBeFreeAndTheAppActive() async throws {
		let people = makePeople()
		let (presenter, _) = await loadedPresenter(people)
		let prompter = try XCTUnwrap(presenter.configurator.reviewPrompter)
		let reopened = try visit(people[0], in: presenter, prompter)
		presenter.view(people[1].id)
		XCTAssertFalse(presenter.takeReviewRequest(reopened), "The viewer opened again during the pause")
		now += 5
		presenter.closeViewer()
		presenter.coverDidClose()
		let covered = try XCTUnwrap(prompter.pendingRequest)
		prompter.appResignedActive()
		XCTAssertNil(prompter.pendingRequest, "Control Center or a notification over the app drops the request")
		prompter.appBecameActive()
		XCTAssertFalse(presenter.takeReviewRequest(covered))
		let added = try visit(people[1], in: presenter, prompter)
		presenter.add()
		XCTAssertFalse(presenter.takeReviewRequest(added), "A new person's page opened during the pause")
		XCTAssertEqual(ReviewPromptStore(defaults: defaults).state.requestCount, 0)
	}

	func testAnAlertOrARemovalKeepsTheRequestAwayForTheSession() async throws {
		let people = makePeople(count: 3)
		let (presenter, _) = await loadedPresenter(people)
		let prompter = try XCTUnwrap(presenter.configurator.reviewPrompter)
		let request = try visit(people[0], in: presenter, prompter)
		presenter.error = SceneError(CoreError.coreDataSaveFailed)
		presenter.error = nil
		XCTAssertFalse(presenter.takeReviewRequest(request), "An alert shown during the pause")
		startNewSession(prompter)
		presenter.view(people[1].id)
		presenter.edit(people[1])
		presenter.editor?.error = SceneError(CoreError.coreDataSaveFailed)
		presenter.editor?.error = nil
		presenter.cancelEditing(presenter.editor)
		now += 5
		presenter.closeViewer()
		presenter.coverDidClose()
		XCTAssertNil(prompter.pendingRequest, "An edit mode's alert")
		startNewSession(prompter)
		presenter.view(people[2].id)
		presenter.edit(people[2])
		now += 5
		presenter.apply(.removed(people[2]), from: presenter.editor)
		presenter.coverDidClose()
		XCTAssertNil(prompter.pendingRequest, "A removal")
		XCTAssertEqual(ReviewPromptStore(defaults: defaults).state.requestCount, 0)
	}

	func testANewPersonsPageIsNoVisit() async throws {
		let (presenter, _) = await loadedPresenter(makePeople())
		let prompter = try XCTUnwrap(presenter.configurator.reviewPrompter)
		presenter.add()
		now += 30
		var added = Person.createPerson()
		added.createdDate = now
		presenter.apply(.saved(added), from: presenter.editor)
		presenter.coverDidClose()
		XCTAssertNil(prompter.pendingRequest)
		XCTAssertEqual(ReviewPromptStore(defaults: defaults).state.viewerVisits, 4)
	}

	func testWithoutAPrompterTheAppNeverAsks() async {
		let people = makePeople()
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		presenter.view(people[0].id)
		presenter.closeViewer()
		presenter.coverDidClose()
		XCTAssertFalse(presenter.takeReviewRequest(UUID()))
	}

	/// Shows `person` for five seconds and returns to the mosaic, which starts a request.
	private func visit(_ person: Person, in presenter: PeoplePresenter, _ prompter: ReviewPrompter) throws -> UUID {
		presenter.view(person.id)
		now += 5
		presenter.closeViewer()
		presenter.coverDidClose()
		return try XCTUnwrap(prompter.pendingRequest)
	}

	/// Leaves the app and comes back, which starts a session with no setbacks.
	private func startNewSession(_ prompter: ReviewPrompter) {
		prompter.appEnteredBackground()
		prompter.appBecameActive()
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
		prompter.appBecameActive()
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
