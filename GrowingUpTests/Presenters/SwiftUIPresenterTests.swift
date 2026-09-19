import Core
import XCTest

@testable import GrowingUp

@MainActor
final class SwiftUIPresenterTests: XCTestCase {
	func testColdWidgetLinkWaitsForLoadAndUsesPinnedCreationOrder() async {
		let gateway = PersonsGatewaySpy()
		var first = Person.createPerson()
		first.createdDate = Date(timeIntervalSince1970: 1)
		first.isOnWidget = true
		var second = Person.createPerson()
		second.createdDate = Date(timeIntervalSince1970: 2)
		second.isOnWidget = true
		gateway.fetchPersonsResultToBeReturned = .success([second, first])
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=1")!)
		await presenter.load()
		XCTAssertEqual(presenter.selectedID, second.id)
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=-1")!)
		XCTAssertEqual(presenter.selectedID, second.id)
	}

	func testLoadErrorIsVisibleAndEndsLoading() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		XCTAssertFalse(presenter.isLoading)
		XCTAssertEqual(presenter.error?.message, CoreError.coreDataFetchFailed.message)
	}

	func testMutationsUpdateVisiblePersonAndReloadWidgets() {
		let gateway = PersonsGatewaySpy()
		var reloadCount = 0
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: { reloadCount += 1 })
		var person = Person.createPerson()
		presenter.apply(.saved(person))
		XCTAssertEqual(presenter.selectedID, person.id)
		person.name = "Updated"
		presenter.apply(.saved(person))
		XCTAssertEqual(presenter.persons.map(\.name), ["Updated"])
		presenter.apply(.removed(person))
		XCTAssertTrue(presenter.persons.isEmpty)
		XCTAssertNil(presenter.selectedID)
		XCTAssertEqual(reloadCount, 3)
	}

	func testSaveFailureRestoresButtonsAndDoesNotDismiss() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([])
		gateway.addPersonResultToBeReturned = .failure(.coreDataSaveFailed)
		var mutations = 0
		let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in mutations += 1 }, onCancel: {})
		await presenter.load()
		presenter.name = "Ada"
		gateway.onAdd = { XCTAssertTrue(presenter.isBusy) }
		await presenter.save()
		XCTAssertFalse(presenter.isBusy)
		XCTAssertEqual(presenter.error?.message, CoreError.coreDataSaveFailed.message)
		XCTAssertEqual(mutations, 0)
	}

	func testDeleteFailureRestoresButtonsAndPreservesPerson() async {
		let gateway = PersonsGatewaySpy()
		gateway.removePersonResultToBeReturned = .failure(.coreDataSaveFailed)
		let person = Person.createPerson()
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in XCTFail("Must not dismiss") }, onCancel: {})
		await presenter.load()
		gateway.onRemove = { XCTAssertTrue(presenter.isBusy) }
		await presenter.remove()
		XCTAssertFalse(presenter.isBusy)
		XCTAssertNotNil(presenter.error)
		XCTAssertEqual(presenter.person, person)
	}

	func testBlankNameDoesNotCallPersistence() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([])
		let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in }, onCancel: {})
		await presenter.load()
		presenter.name = "  "
		await presenter.save()
		XCTAssertFalse(gateway.addPersonCalled)
		XCTAssertEqual(presenter.error?.message, CoreError.noNameValue.message)
	}

	func testCancelDoesNotSaveDraft() async {
		let gateway = PersonsGatewaySpy()
		var cancelled = false
		let presenter = SceneConfigurator(gateway: gateway).editor(person: .createPerson(), onMutation: { _ in }, onCancel: { cancelled = true })
		await presenter.load()
		presenter.name = "Unsaved"
		presenter.cancel()
		XCTAssertTrue(cancelled)
		XCTAssertFalse(gateway.editPersonCalled)
	}

	func testOverviewAgeUsesProvidedClockAndClearsMissingPicture() async {
		var person = Person.createPerson()
		person.appPicId = nil
		let presenter = OverviewPresenter(loadImage: { _ in
			XCTFail("No image to load"); return UIImage()
		})
		let now = person.birthday.addingTimeInterval(120)
		presenter.tick(person: person, now: now)
		XCTAssertEqual(presenter.age, AgeCalculator.ageString(for: person.dateComponents(at: now)))
		await presenter.load(person: person)
		XCTAssertNil(presenter.image)
	}
}
