import Core
import XCTest

@testable import GrowingUp

@MainActor
final class PeopleSelectionTests: XCTestCase {
	func testLaunchAlwaysShowsTheMosaic() async {
		let presenter = await loadedPresenter(makePeople(count: 3))
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.selectedID)
	}

	func testATileOpensItsPersonAndThePagerMovesTheZoomSource() async {
		let people = makePeople(count: 3)
		let presenter = await loadedPresenter(people)
		presenter.view(people[1].id)
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, people[1].id)
		presenter.select(people[2].id)
		XCTAssertEqual(presenter.selectedID, people[2].id)
		presenter.select(UUID())
		XCTAssertEqual(presenter.selectedID, people[2].id, "A person who is no longer listed keeps the current page")
		presenter.closeViewer()
		XCTAssertFalse(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, people[2].id, "The viewer closes into the last shown person's tile")
	}

	func testUnknownPersonDoesNotOpenTheViewer() async {
		let presenter = await loadedPresenter(makePeople(count: 2))
		presenter.view(UUID())
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.selectedID)
	}

	func testANewPersonLandsOnTheMosaicAndAnEditStaysInTheViewer() async {
		let people = makePeople(count: 2)
		let presenter = await loadedPresenter(people)
		presenter.view(people[0].id)
		var edited = people[0]
		edited.name = "Edited"
		presenter.apply(.saved(edited))
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, edited.id)
		var added = Person.createPerson()
		added.createdDate = Date(timeIntervalSince1970: 100)
		presenter.apply(.saved(added))
		XCTAssertFalse(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, added.id, "The mosaic scrolls to the new tile")
		XCTAssertEqual(presenter.persons.last?.id, added.id)
	}

	func testRemovingTheShownPersonReturnsToTheMosaic() async {
		let people = makePeople(count: 3)
		let presenter = await loadedPresenter(people)
		presenter.view(people[1].id)
		presenter.apply(.removed(people[1]))
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.selectedID)
		XCTAssertEqual(presenter.persons.map(\.id), [people[0].id, people[2].id])
	}

	func testAWidgetLinkClosesTheEditorAndOpensThePersonOverTheMosaic() async {
		let people = makePeople(count: 2)
		let presenter = await loadedPresenter(people)
		presenter.add()
		XCTAssertNotNil(presenter.editor)
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIDKey)=\(people[1].id.uuidString)")!)
		XCTAssertNil(presenter.editor)
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, people[1].id)
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
