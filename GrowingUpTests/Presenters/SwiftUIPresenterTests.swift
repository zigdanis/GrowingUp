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
		let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in mutations += 1 })
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
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in XCTFail("Must not dismiss") })
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
		let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in })
		await presenter.load()
		presenter.name = "  "
		await presenter.save()
		XCTAssertFalse(gateway.addPersonCalled)
		XCTAssertEqual(presenter.error?.message, CoreError.noNameValue.message)
	}

	func testBirthdayFieldsPreserveTheOtherComponentAndSaveCombinedDate() async {
		let gateway = PersonsGatewaySpy()
		var person = Person.createPerson()
		let calendar = Calendar.current
		person.birthday = calendar.date(from: DateComponents(year: 2020, month: 1, day: 2, hour: 15, minute: 8))!
		gateway.editPersonResultToBeReturned = .success(person)
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in })
		await presenter.load()
		presenter.dayOfBirth = calendar.date(from: DateComponents(year: 2021, month: 3, day: 4))!
		XCTAssertEqual(calendar.component(.hour, from: presenter.birthday), 15)
		XCTAssertEqual(calendar.component(.minute, from: presenter.birthday), 8)
		presenter.timeOfBirth = calendar.date(from: DateComponents(year: 2024, month: 5, day: 6, hour: 9, minute: 30))!
		let expected = calendar.date(from: DateComponents(year: 2021, month: 3, day: 4, hour: 9, minute: 30))!
		XCTAssertEqual(presenter.birthday, expected)
		presenter.isOnWidget = false
		await presenter.save()
		XCTAssertEqual(gateway.addPersonParameters.dayOfBirth, expected)
		XCTAssertEqual(gateway.addPersonParameters.timeOfBirth, expected)
	}

	func testBirthdayFieldsClampFutureDateAndTime() {
		let gateway = PersonsGatewaySpy()
		let calendar = Calendar.current
		let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12, minute: 0))!
		let presenter = SceneConfigurator(gateway: gateway, now: { now }).editor(person: nil, onMutation: { _ in })
		presenter.timeOfBirth = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1, hour: 18, minute: 30))!
		XCTAssertEqual(presenter.birthday, now)
		presenter.dayOfBirth = now.addingTimeInterval(86_400)
		XCTAssertEqual(presenter.birthday, now)
		presenter.dayOfBirth = now.addingTimeInterval(-86_400)
		presenter.timeOfBirth = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1, hour: 18, minute: 30))!
		XCTAssertEqual(presenter.birthday, calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 18, minute: 30))!)
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
	func testFourthPinIsRejectedBeforeSavingAndRestoresActions() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success((0..<3).map { _ in Person.createPerson() })
		let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in XCTFail("Pin limit") })
		await presenter.load()
		presenter.name = "Fourth"
		presenter.isOnWidget = true
		await presenter.save()
		XCTAssertFalse(gateway.addPersonCalled)
		XCTAssertFalse(presenter.isBusy)
		XCTAssertEqual(presenter.error?.message, CoreError(message: "Unable to add more than 3 persons").message)
	}

	func testExistingPinnedPersonCanBeEditedAtPinLimit() async {
		let gateway = PersonsGatewaySpy()
		var person = Person.createPerson()
		person.isOnWidget = true
		gateway.fetchPersonsResultToBeReturned = .success([person, .createPerson(), .createPerson()])
		gateway.editPersonResultToBeReturned = .success(person)
		var saved = false
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in saved = true })
		await presenter.load()
		await presenter.save()
		XCTAssertTrue(saved)
		XCTAssertTrue(gateway.editPersonCalled)
		XCTAssertNil(presenter.error)
	}

	func testExistingUnpinnedPersonCannotBecomeFourthPin() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success((0..<3).map { _ in Person.createPerson() })
		let presenter = SceneConfigurator(gateway: gateway).editor(person: .createPerson(), onMutation: { _ in XCTFail("Pin limit") })
		await presenter.load()
		presenter.isOnWidget = true
		await presenter.save()
		XCTAssertFalse(gateway.editPersonCalled)
		XCTAssertFalse(presenter.isBusy)
		XCTAssertNotNil(presenter.error)
	}

	func testUnpinDoesNotRequireCapacityFetch() async {
		let gateway = PersonsGatewaySpy()
		var person = Person.createPerson()
		person.isOnWidget = true
		gateway.editPersonResultToBeReturned = .success(person)
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in })
		await presenter.load()
		presenter.isOnWidget = false
		await presenter.save()
		XCTAssertTrue(gateway.editPersonCalled)
		XCTAssertFalse(gateway.addPersonParameters.isOnWidget)
		XCTAssertNil(presenter.error)
	}

	func testCancellationRestoresActionsWithoutErrorOrMutation() async {
		let gateway = CancelledSaveGateway()
		gateway.fetchPersonsResultToBeReturned = .success([])
		let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in XCTFail("Cancelled") })
		await presenter.load()
		presenter.name = "Ada"
		await presenter.save()
		XCTAssertFalse(presenter.isBusy)
		XCTAssertNil(presenter.error)
	}

}
