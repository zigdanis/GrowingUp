import Core
import XCTest

@testable import GrowingUp

@MainActor
final class PeopleSelectionTests: XCTestCase {
	func testAvatarsSelectPeopleAndThePlusSelectsTheAddPage() async {
		let people = makePeople(count: 2)
		let presenter = await loadedPresenter(people)
		XCTAssertEqual(presenter.selectedID, people[0].id)
		presenter.select(people[1].id)
		XCTAssertEqual(presenter.selectedID, people[1].id)
		presenter.select(nil)
		XCTAssertNil(presenter.selectedID)
		presenter.select(people[0].id)
		XCTAssertEqual(presenter.selectedID, people[0].id)
		presenter.select(UUID())
		XCTAssertEqual(presenter.selectedID, people[0].id, "A person who is no longer listed keeps the current page")
	}

	func testAddPageCannotBeSelectedOnceThePeopleLimitIsReached() async {
		let people = makePeople(count: 20)
		let presenter = await loadedPresenter(people)
		XCTAssertFalse(presenter.canAdd)
		presenter.select(nil)
		XCTAssertEqual(presenter.selectedID, people[0].id)
	}

	private func loadedPresenter(_ people: [Person]) async -> PeoplePresenter {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		return presenter
	}

	private func makePeople(count: Int) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
	}
}
