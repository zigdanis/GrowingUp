import Core
import XCTest

@testable import GrowingUp

/// A failed read of the people leaves them unavailable rather than empty, and a later read, such as from Try Again or on
/// return to the app, brings them back without opening anything; once they are loaded, reads change nothing.
@MainActor
final class PeopleLibraryTests: XCTestCase {
	func testAFailedFirstReadIsUnavailableUntilARetrySucceedsAndIsReportedOnce() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let analytics = AnalyticsGatewaySpy()
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway, analytics: analytics), reloadWidgets: {})
		await presenter.load()
		XCTAssertEqual(presenter.library.state, .unavailable(isRetrying: false))
		XCTAssertTrue(presenter.persons.isEmpty)
		XCTAssertNil(presenter.error)
		await presenter.load()
		XCTAssertEqual(presenter.library.state, .unavailable(isRetrying: false))
		XCTAssertEqual(analytics.operations, ["load_people"], "A retry that fails again is no new ticket")

		let people = makePeople(count: 2)
		gateway.fetchPersonsResultToBeReturned = .success(people.reversed())
		await presenter.load()
		XCTAssertEqual(presenter.library.state, .loaded)
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id))
		XCTAssertEqual(analytics.contexts, [AnalyticsContext(people: people)])
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.editor)
		XCTAssertEqual(analytics.operations, ["load_people"])
	}

	func testARetryIsMarkedWhileItReadsAndASecondOneWaitsForIt() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		var gate: CheckedContinuation<Void, Never>?
		gateway.onFetch = { await withCheckedContinuation { gate = $0 } }
		gateway.fetchPersonsResultToBeReturned = .success(makePeople(count: 1))
		let retry = Task { await presenter.load() }
		while gate == nil { await Task.yield() }
		XCTAssertEqual(presenter.library.state, .unavailable(isRetrying: true))
		let returned = Task { await presenter.load() }
		for _ in 0..<5 { await Task.yield() }
		gate?.resume()
		await retry.value
		await returned.value
		XCTAssertEqual(gateway.fetchPersonsCount, 2, "Return to the app during Try Again waits for it and reads nothing more")
		XCTAssertEqual(presenter.library.state, .loaded)
		XCTAssertEqual(presenter.persons.count, 1)
	}

	func testReadingAgainOnceLoadedKeepsThePeopleAndTheOpenEditor() async throws {
		let people = makePeople(count: 2)
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		presenter.edit(people[1])
		let editor = try XCTUnwrap(presenter.editor)
		gateway.fetchPersonsResultToBeReturned = .success([])
		await presenter.load()
		XCTAssertEqual(gateway.fetchPersonsCount, 1)
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id))
		XCTAssertTrue(presenter.editor === editor)
	}

	func testAReadWhoseCallerIsCancelledStillLoadsThePeopleARequestMeanwhileWaitedFor() async {
		let people = makePeople(count: 1)
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		var gate: CheckedContinuation<Void, Never>?
		gateway.onFetch = {
			await withCheckedContinuation { gate = $0 }
			try Task.checkCancellation()
		}
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		presenter.open(URL(string: "growingup-app://?personID=\(people[0].id.uuidString)")!)
		// The app leaves the foreground during the read, then comes back before it ends.
		let first = Task { await presenter.load() }
		while gate == nil { await Task.yield() }
		first.cancel()
		let second = Task { await presenter.load() }
		for _ in 0..<5 { await Task.yield() }
		gate?.resume()
		await first.value
		await second.value
		XCTAssertEqual(gateway.fetchPersonsCount, 1)
		XCTAssertEqual(presenter.library.state, .loaded)
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id))
		XCTAssertEqual(presenter.selectedID, people[0].id, "The widget link opens its person once the read ends")
		XCTAssertTrue(presenter.isViewing)
	}

	func testACancelledFirstReadStaysLoadingAndReportsNothing() async {
		let people = makePeople(count: 1)
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		gateway.onFetch = { throw CancellationError() }
		let analytics = AnalyticsGatewaySpy()
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway, analytics: analytics), reloadWidgets: {})
		presenter.open(URL(string: "growingup-app://?personID=\(people[0].id.uuidString)")!)
		await presenter.load()
		XCTAssertEqual(presenter.library.state, .loading)
		XCTAssertTrue(analytics.failures.isEmpty)

		gateway.onFetch = nil
		await presenter.load()
		XCTAssertEqual(presenter.library.state, .loaded)
		XCTAssertEqual(presenter.selectedID, people[0].id, "A cancelled read keeps the widget link for the next one")
		XCTAssertTrue(presenter.isViewing)
	}

	func testACancelledRetryIsUnavailableAgain() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		gateway.onFetch = { throw CancellationError() }
		await presenter.load()
		XCTAssertEqual(presenter.library.state, .unavailable(isRetrying: false))
	}

	func testALinkBeforeAFailedReadIsDroppedButOneWhileUnavailableOpensAfterTheRetry() async throws {
		let people = makePeople(count: 2)
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		let addLink = try XCTUnwrap(URL(string: "growingup-app://\(Constants.widgetAddPersonHost)"))
		presenter.open(addLink)
		await presenter.load()
		XCTAssertNil(presenter.editor, "The library is unknown, so no first person is offered")
		gateway.fetchPersonsResultToBeReturned = .success(people)
		await presenter.load()
		XCTAssertNil(presenter.editor, "A link from before the failure opens nothing after a later read")
		XCTAssertFalse(presenter.isViewing)

		let failing = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		await failing.load()
		failing.open(try XCTUnwrap(URL(string: "growingup-app://?personID=\(people[1].id.uuidString)")))
		XCTAssertFalse(failing.isViewing, "The person waits for the people")
		gateway.fetchPersonsResultToBeReturned = .success(people)
		await failing.load()
		XCTAssertEqual(failing.selectedID, people[1].id)
		XCTAssertTrue(failing.isViewing)
	}

	private func makePeople(count: Int) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.displayOrder = index + 1
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
	}
}
