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
		presenter.edit(people[0])
		presenter.apply(.saved(edited), from: presenter.editor)
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, edited.id)
		var added = Person.createPerson()
		added.createdDate = Date(timeIntervalSince1970: 100)
		presenter.add()
		presenter.apply(.saved(added), from: presenter.editor)
		XCTAssertFalse(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, added.id, "The mosaic scrolls to the new tile")
		XCTAssertEqual(presenter.persons.last?.id, added.id)
	}

	func testRemovingTheShownPersonReturnsToTheMosaicWhereTheirTileLeaves() async {
		let people = makePeople(count: 3)
		let presenter = await loadedPresenter(people)
		presenter.view(people[1].id)
		presenter.edit(people[1])
		presenter.apply(.removed(people[1]), from: presenter.editor)
		XCTAssertFalse(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, people[1].id, "The viewer zooms back into the removed person's tile")
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id), "The tile waits for the viewer")
		presenter.view(people[1].id)
		XCTAssertFalse(presenter.isViewing, "A leaving tile opens nobody")
		presenter.coverDidClose()
		XCTAssertNil(presenter.selectedID)
		XCTAssertEqual(presenter.persons.map(\.id), [people[0].id, people[2].id])
	}

	func testRemovingTheLastPersonLeavesTheEmptyMosaic() async throws {
		let people = makePeople(count: 1)
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		gateway.removePersonResultToBeReturned = .success(())
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		presenter.view(people[0].id)
		presenter.edit(people[0])
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.remove()
		presenter.coverDidClose()
		XCTAssertTrue(presenter.persons.isEmpty)
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.selectedID)
		XCTAssertTrue(presenter.canAdd, "The empty mosaic still offers Add")
	}

	func testAViewerOpenedBeforeTheCoverClosedLetsTheRemovedTileLeave() async {
		let people = makePeople(count: 3)
		let presenter = await loadedPresenter(people)
		presenter.view(people[1].id)
		presenter.edit(people[1])
		presenter.apply(.removed(people[1]), from: presenter.editor)
		presenter.view(people[2].id)
		XCTAssertEqual(presenter.persons.map(\.id), [people[0].id, people[2].id])
		presenter.coverDidClose()
		XCTAssertTrue(presenter.isViewing, "The cover that opened again stays")
		XCTAssertEqual(presenter.selectedID, people[2].id)
	}

	func testNeighboursFollowTheMosaicOrderAndEndAtEitherEnd() async {
		let people = makePeople(count: 3)
		let presenter = await loadedPresenter(people)
		XCTAssertEqual(presenter.neighbour(of: people[1].id, by: 1), people[2].id)
		XCTAssertEqual(presenter.neighbour(of: people[1].id, by: -1), people[0].id)
		XCTAssertNil(presenter.neighbour(of: people[2].id, by: 1))
		XCTAssertNil(presenter.neighbour(of: people[0].id, by: -1))
		XCTAssertNil(presenter.neighbour(of: UUID(), by: 1))
		presenter.view(people[0].id)
		presenter.select(presenter.neighbour(of: people[0].id, by: 1)!)
		XCTAssertEqual(presenter.selectedID, people[1].id, "VoiceOver's Next person pages the viewer")
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

	func testMutationsUpdateVisiblePersonAndReloadWidgets() {
		let gateway = PersonsGatewaySpy()
		var reloadCount = 0
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: { reloadCount += 1 })
		var person = Person.createPerson()
		presenter.add()
		presenter.apply(.saved(person), from: presenter.editor)
		XCTAssertEqual(presenter.selectedID, person.id)
		XCTAssertNil(presenter.editor)
		person.name = "Updated"
		presenter.edit(person)
		presenter.apply(.saved(person), from: presenter.editor)
		XCTAssertEqual(presenter.persons.map(\.name), ["Updated"])
		presenter.edit(person)
		presenter.apply(.removed(person), from: presenter.editor)
		XCTAssertTrue(presenter.persons.isEmpty)
		XCTAssertNil(presenter.selectedID)
		XCTAssertEqual(reloadCount, 3)
	}

	func testASaveThatAWidgetLinkInterruptedKeepsTheLinkedPersonShown() async throws {
		let people = makePeople(count: 2)
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		var added = Person.createPerson()
		added.createdDate = Date(timeIntervalSince1970: 100)
		gateway.addPersonResultToBeReturned = .success(added)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		presenter.add()
		let saving = try XCTUnwrap(presenter.editor)
		await saving.load()
		saving.name = added.name
		gateway.onAdd = {
			presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIDKey)=\(people[1].id.uuidString)")!)
			presenter.edit(people[1])
		}
		await saving.save()
		XCTAssertEqual(presenter.persons.last?.id, added.id, "The saved person still joins the mosaic")
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, people[1].id)
		XCTAssertNotNil(presenter.editor, "The newer editor stays open")
		XCTAssertFalse(presenter.editor === saving)
	}

	func testARemovalFromAReplacedEditorClosesAViewerShowingTheRemovedPerson() async {
		let people = makePeople(count: 3)
		let presenter = await loadedPresenter(people)
		presenter.edit(people[1])
		let removing = presenter.editor
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIDKey)=\(people[2].id.uuidString)")!)
		presenter.apply(.removed(people[0]), from: removing)
		XCTAssertTrue(presenter.isViewing, "Another person's viewer stays open")
		XCTAssertEqual(presenter.selectedID, people[2].id)
		presenter.apply(.removed(people[2]), from: removing)
		XCTAssertFalse(presenter.isViewing, "Nothing is left to show")
		presenter.coverDidClose()
		XCTAssertNil(presenter.selectedID)
		XCTAssertEqual(presenter.persons.map(\.id), [people[1].id])
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
