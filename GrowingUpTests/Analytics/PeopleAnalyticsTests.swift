import Core
import XCTest

@testable import GrowingUp

/// The mosaic and the viewer record where people are opened from, how editing sessions end and what changed, with
/// counts that leave out a removed person whose tile is still leaving.
@MainActor
final class PeopleAnalyticsTests: XCTestCase {
	func testLoadingSetsTheCountsAndAFailedLoadIsReported() async {
		var people = makePeople(count: 3)
		people[0].isOnWidget = true
		let (_, analytics) = await loadedPresenter(people)
		XCTAssertEqual(analytics.contexts, [AnalyticsContext(peopleCount: 3, widgetPeopleCount: 1)])
		XCTAssertEqual(analytics.events, [])

		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let failing = AnalyticsGatewaySpy()
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway, analytics: failing), reloadWidgets: {})
		await presenter.load()
		XCTAssertNotNil(presenter.error)
		XCTAssertEqual(failing.operations, ["load_people"])
	}

	func testViewsAreTrackedByTheirSource() async throws {
		let people = makePeople(count: 3)
		let (presenter, analytics) = await loadedPresenter(people)
		presenter.view(people[0].id)
		presenter.select(people[0].id)
		XCTAssertEqual(analytics.events, [.personViewed(source: .tile)], "The pager reporting its own page is no swipe")
		presenter.select(people[1].id)
		XCTAssertEqual(analytics.events.last, .personViewed(source: .swipe))
		presenter.closeViewer()
		presenter.open(try XCTUnwrap(URL(string: "growingup-app://?personID=\(people[2].id.uuidString)")))
		XCTAssertEqual(
			analytics.events.suffix(2), [.widgetLinkOpened(target: .person), .personViewed(source: .widget)])
		XCTAssertFalse(analytics.events.contains { $0.name == "person_editor_closed" }, "Viewing opens no editor")
	}

	func testAddingAPersonTracksTheOpenedEditorTheSaveAndTheCounts() async throws {
		let people = makePeople(count: 2)
		let gateway = PersonsGatewaySpy()
		let (presenter, analytics) = await loadedPresenter(people, gateway: gateway)
		var added = Person.createPerson()
		added.name = "Ada"
		added.isOnWidget = true
		added.displayOrder = 3
		gateway.addPersonResultToBeReturned = .success(added)
		presenter.add()
		XCTAssertEqual(analytics.events, [.personEditorOpened(isNewPerson: true, source: .addButton)])
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		mode.editor.name = "Ada"
		await mode.done()
		let saved = PersonSavedProperties(saved: added, previous: nil, people: people + [added])
		XCTAssertEqual(
			analytics.events.suffix(2),
			[.personSaved(saved), .personEditorClosed(isNewPerson: true, outcome: .saved)])
		XCTAssertEqual(saved.peopleCount, 3)
		XCTAssertEqual(analytics.contexts.last, AnalyticsContext(peopleCount: 3, widgetPeopleCount: 1))
	}

	func testCancelClosesTheEditorAsCancelled() async throws {
		let people = makePeople(count: 2)
		let (presenter, analytics) = await loadedPresenter(people)
		presenter.view(people[1].id)
		presenter.edit(people[1])
		XCTAssertEqual(analytics.events.last, .personEditorOpened(isNewPerson: false, source: .viewer))
		try XCTUnwrap(presenter.editMode).cancel()
		XCTAssertEqual(analytics.events.last, .personEditorClosed(isNewPerson: false, outcome: .cancelled))
	}

	func testARemovedPersonLeavesTheCountsBeforeTheirTileLeaves() async throws {
		let people = makePeople(count: 3)
		let gateway = PersonsGatewaySpy()
		let (presenter, analytics) = await loadedPresenter(people, gateway: gateway)
		gateway.removePersonResultToBeReturned = .success(())
		presenter.view(people[1].id)
		presenter.edit(people[1])
		try await XCTUnwrap(presenter.editMode).remove()
		XCTAssertTrue(presenter.persons.contains { $0.id == people[1].id }, "The tile waits for the viewer to close")
		XCTAssertEqual(
			analytics.events.suffix(2),
			[.personRemoved(peopleCount: 2), .personEditorClosed(isNewPerson: false, outcome: .removed)])
		XCTAssertEqual(analytics.contexts.last, AnalyticsContext(peopleCount: 2, widgetPeopleCount: 0))
	}

	func testTheWidgetsAddLinkOpensTheEditorFromTheWidget() async throws {
		let (presenter, analytics) = await loadedPresenter(makePeople(count: 1))
		presenter.open(try XCTUnwrap(URL(string: "growingup-app://add-person")))
		XCTAssertEqual(
			analytics.events,
			[.widgetLinkOpened(target: .addPerson), .personEditorOpened(isNewPerson: true, source: .widget)])
	}

	func testAStoredOrderIsTrackedAndAFailedOneReported() async {
		let people = makePeople(count: 3)
		let gateway = PersonsGatewaySpy()
		let (presenter, analytics) = await loadedPresenter(people, gateway: gateway)
		presenter.shift(people[0].id, by: 1)
		await presenter.saveOrder()
		XCTAssertEqual(analytics.events, [.peopleReordered(peopleCount: 3)])
		gateway.reorderResultToBeReturned = .failure(.coreDataSaveFailed)
		presenter.shift(people[0].id, by: 1)
		await presenter.saveOrder()
		XCTAssertEqual(analytics.operations, ["save_order"])
		XCTAssertEqual(analytics.events.count, 1)
	}

	private func loadedPresenter(
		_ people: [Person], gateway: PersonsGatewaySpy = PersonsGatewaySpy()
	) async -> (PeoplePresenter, AnalyticsGatewaySpy) {
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let analytics = AnalyticsGatewaySpy()
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway, analytics: analytics), reloadWidgets: {})
		await presenter.load()
		return (presenter, analytics)
	}

	private func makePeople(count: Int) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.name = "Person \(index)"
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
	}
}
