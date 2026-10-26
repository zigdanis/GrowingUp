import Core
import XCTest

@testable import GrowingUp

/// A new person grows out of "Add" as an empty in-place edit mode in the cover; Done adds them to the end of the mosaic
/// and Cancel drops them without a question.
@MainActor
final class PeopleNewPersonTests: XCTestCase {
	func testAddOpensAnEmptyEditModeOutOfTheAddButton() async throws {
		let people = makePeople(count: 2)
		let (presenter, _) = await loadedPresenter(people)
		presenter.view(people[1].id)
		presenter.closeViewer()
		presenter.add()
		XCTAssertTrue(presenter.isViewing)
		XCTAssertTrue(presenter.isAddingPerson, "The cover shows the new person rather than the viewer's pages")
		XCTAssertNil(presenter.selectedID, "No person names the zoom source, so the cover grows out of the Add button")
		let mode = try XCTUnwrap(presenter.editMode)
		XCTAssertTrue(mode.isNewPerson)
		XCTAssertNil(mode.editor.person)
		XCTAssertEqual(mode.editor.name, "")
		XCTAssertFalse(mode.showsRemoveButton, "A new person has nobody to remove")
		XCTAssertFalse(mode.showsWidgetPictureButton, "Nor a photo to frame a widget picture from")
		await mode.editor.load()
		XCTAssertFalse(mode.canSave)
		mode.editor.name = "   "
		XCTAssertFalse(mode.canSave, "A blank name cannot be added")
		mode.editor.name = "Ada"
		XCTAssertTrue(mode.canSave, "A name is all a new person needs; the photo is optional")
		XCTAssertTrue(mode.canCancel)
	}

	func testDoneAddsThePersonWithoutAPhotoToTheEndOfTheMosaic() async throws {
		var people = makePeople(count: 2)
		people[0].displayOrder = 2
		people[1].displayOrder = 1
		let (presenter, gateway) = await loadedPresenter(people)
		var added = Person.createPerson()
		added.name = "Ada"
		added.appPicId = nil
		added.widgetPicId = nil
		added.displayOrder = 3
		gateway.addPersonResultToBeReturned = .success(added)
		presenter.add()
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		mode.editor.name = "Ada"
		await mode.done()
		XCTAssertTrue(gateway.addPersonCalled)
		XCTAssertEqual(gateway.addPersonParameters.name, "Ada")
		XCTAssertNil(gateway.addPersonParameters.appImage)
		XCTAssertNil(gateway.addPersonParameters.widgetImage)
		XCTAssertEqual(presenter.persons.map(\.id), [people[1].id, people[0].id, added.id])
		XCTAssertFalse(presenter.isViewing, "The new person's page shrinks into their tile")
		XCTAssertFalse(presenter.isAddingPerson)
		XCTAssertEqual(presenter.selectedID, added.id, "The mosaic scrolls to the new tile")
		XCTAssertNil(presenter.editMode)
		XCTAssertNil(presenter.editor)
	}

	func testCancelAddsNobodyAndAsksNothing() async throws {
		let people = makePeople(count: 2)
		let (presenter, gateway) = await loadedPresenter(people)
		presenter.add()
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		mode.editor.name = "Unsaved"
		mode.cancel()
		XCTAssertFalse(gateway.addPersonCalled)
		XCTAssertFalse(mode.isConfirmingRemoval)
		XCTAssertNil(mode.popover)
		XCTAssertNil(mode.editor.error)
		XCTAssertFalse(presenter.isViewing, "Cancel closes the cover at once")
		XCTAssertNil(presenter.editor)
		XCTAssertNil(presenter.selectedID, "The empty page shrinks back into the Add button")
		XCTAssertTrue(presenter.isAddingPerson, "The empty page stays until the cover has closed")
		presenter.coverDidClose()
		XCTAssertFalse(presenter.isAddingPerson)
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id))
	}

	func testAFailedAddKeepsTheDraftOpenForAnotherTry() async throws {
		let (presenter, gateway) = await loadedPresenter(makePeople(count: 1))
		gateway.addPersonResultToBeReturned = .failure(.coreDataSaveFailed)
		presenter.add()
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		mode.editor.name = "Ada"
		await mode.done()
		XCTAssertNotNil(mode.editor.error)
		XCTAssertTrue(presenter.editMode === mode)
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.persons.count, 1)
		XCTAssertTrue(mode.canSave)
	}

	func testTheWidgetsAddLinkOpensTheNewPersonOverTheViewer() async throws {
		let people = makePeople(count: 2)
		let (presenter, _) = await loadedPresenter(people)
		presenter.view(people[0].id)
		presenter.open(URL(string: "growingup-app://\(Constants.widgetAddPersonHost)")!)
		XCTAssertTrue(presenter.isViewing)
		XCTAssertTrue(presenter.isAddingPerson)
		XCTAssertTrue(try XCTUnwrap(presenter.editMode).isNewPerson)
		// A person link replaces the draft with that person's page.
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIDKey)=\(people[1].id.uuidString)")!)
		XCTAssertFalse(presenter.isAddingPerson)
		XCTAssertNil(presenter.editMode)
		XCTAssertEqual(presenter.selectedID, people[1].id)
	}

	func testANewCoverOpenedBeforeTheOldOneClosedKeepsItsDraft() async throws {
		let (presenter, _) = await loadedPresenter(makePeople(count: 1))
		presenter.add()
		presenter.closeViewer()
		presenter.add()
		presenter.coverDidClose()
		XCTAssertTrue(presenter.isAddingPerson)
		XCTAssertNotNil(presenter.editMode)
	}

	private func loadedPresenter(_ people: [Person]) async -> (PeoplePresenter, PersonsGatewaySpy) {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		return (presenter, gateway)
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
