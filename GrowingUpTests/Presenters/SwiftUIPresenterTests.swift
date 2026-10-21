import Core
import XCTest

@testable import GrowingUp

@MainActor
final class SwiftUIPresenterTests: XCTestCase {
	func testColdWidgetLinkWaitsForLoadAndUsesSixthPinnedCreationOrder() async {
		let gateway = PersonsGatewaySpy()
		let pinned = pinnedPeople(count: Constants.widgetPeopleLimit)
		var unpinned = Person.createPerson()
		unpinned.createdDate = Date(timeIntervalSince1970: -1)
		unpinned.isOnWidget = false
		gateway.fetchPersonsResultToBeReturned = .success([unpinned] + pinned.reversed())
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=5")!)
		await presenter.load()
		XCTAssertEqual(presenter.selectedID, pinned[5].id)
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=-1")!)
		XCTAssertEqual(presenter.selectedID, pinned[5].id)
	}

	func testStableWidgetLinkWaitsForLoadAndFindsUnpinnedPerson() async {
		let gateway = PersonsGatewaySpy()
		let pinned = pinnedPeople(count: 2)
		var target = Person.createPerson()
		target.isOnWidget = false
		gateway.fetchPersonsResultToBeReturned = .success(pinned + [target])
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		let widgetPerson = WidgetPerson(id: target.id, index: 0, name: target.name, birthday: target.birthday, image: nil)
		presenter.open(widgetPerson.deepLinkURL)
		XCTAssertNil(presenter.selectedID)
		await presenter.load()
		XCTAssertEqual(presenter.selectedID, target.id)
		presenter.select(pinned[0].id)
		presenter.open(widgetPerson.deepLinkURL)
		XCTAssertEqual(presenter.selectedID, target.id)
	}

	func testUnknownOrInvalidWidgetUUIDDoesNotFallBackToIndex() async {
		let gateway = PersonsGatewaySpy()
		let pinned = pinnedPeople(count: 2)
		gateway.fetchPersonsResultToBeReturned = .success(pinned)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		presenter.open(URL(string: "growingup-app://?personID=\(UUID().uuidString)&personIndex=1")!)
		await presenter.load()
		XCTAssertEqual(presenter.selectedID, pinned[0].id)
		for value in [UUID().uuidString, "invalid"] {
			presenter.open(URL(string: "growingup-app://?personID=\(value)&personIndex=1")!)
			XCTAssertEqual(presenter.selectedID, pinned[0].id)
		}
		presenter.open(URL(string: "growingup-app://?personIndex=1")!)
		XCTAssertEqual(presenter.selectedID, pinned[1].id)
	}

	func testStaleWidgetLinkAfterRemovalDoesNotSelectReplacement() async {
		let gateway = PersonsGatewaySpy()
		let pinned = pinnedPeople(count: 3)
		gateway.fetchPersonsResultToBeReturned = .success(pinned)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		presenter.apply(.removed(pinned[1]))
		presenter.select(pinned[0].id)
		presenter.open(URL(string: "growingup-app://?personID=\(pinned[1].id.uuidString)")!)
		XCTAssertEqual(presenter.selectedID, pinned[0].id)
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
		XCTAssertFalse(presenter.canSave)
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
		XCTAssertEqual(presenter.summary, AgeSummary(birthday: person.birthday, now: now, finestUnit: .minutes))
		await presenter.load(person: person)
		XCTAssertNil(presenter.image)
	}
	func testFourthAndSixthPinsSaveWithAvailableCapacity() async {
		for count in [3, 5] {
			let gateway = PersonsGatewaySpy()
			gateway.fetchPersonsResultToBeReturned = .success(pinnedPeople(count: count))
			gateway.addPersonResultToBeReturned = .success(.createPerson())
			var saved = false
			let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in saved = true })
			await presenter.load()
			XCTAssertTrue(presenter.isOnWidget)
			presenter.name = "Person \(count + 1)"
			await presenter.save()
			XCTAssertTrue(saved)
			XCTAssertTrue(gateway.addPersonCalled)
			XCTAssertTrue(gateway.addPersonParameters.isOnWidget)
			XCTAssertNil(presenter.error)
		}
	}

	func testSeventhPinIsRejectedBeforeSavingAndRestoresActions() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(pinnedPeople(count: Constants.widgetPeopleLimit))
		let presenter = SceneConfigurator(gateway: gateway).editor(person: nil, onMutation: { _ in XCTFail("Pin limit") })
		await presenter.load()
		XCTAssertFalse(presenter.isOnWidget)
		presenter.name = "Seventh"
		presenter.isOnWidget = true
		await presenter.save()
		XCTAssertFalse(gateway.addPersonCalled)
		XCTAssertFalse(presenter.isBusy)
		XCTAssertEqual(presenter.error?.message, CoreError.widgetPeopleLimitReached.message)
	}

	func testExistingPinnedPersonCanBeEditedAtPinLimit() async {
		let gateway = PersonsGatewaySpy()
		var person = Person.createPerson()
		person.isOnWidget = true
		gateway.fetchPersonsResultToBeReturned = .success([person] + pinnedPeople(count: Constants.widgetPeopleLimit - 1))
		gateway.editPersonResultToBeReturned = .success(person)
		var saved = false
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in saved = true })
		await presenter.load()
		presenter.name += " Updated"
		await presenter.save()
		XCTAssertTrue(saved)
		XCTAssertTrue(gateway.editPersonCalled)
		XCTAssertNil(presenter.error)
	}

	func testExistingUnpinnedPersonCannotBecomeSeventhPin() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(pinnedPeople(count: Constants.widgetPeopleLimit))
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

	private func pinnedPeople(count: Int) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.isOnWidget = true
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
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

extension SwiftUIPresenterTests {
	func testAddPersonWidgetLinkWaitsForLoadAndRespectsTheLimit() async {
		let link = URL(string: "growingup-app://\(Constants.widgetAddPersonHost)")!
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(pinnedPeople(count: 2))
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		presenter.open(link)
		XCTAssertNil(presenter.editor)
		await presenter.load()
		XCTAssertNotNil(presenter.editor)
		XCTAssertNil(presenter.editor?.person)
		presenter.editor = nil
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=1")!)
		XCTAssertEqual(presenter.selectedID, presenter.persons[1].id)
		XCTAssertNil(presenter.editor)
		presenter.open(link)
		XCTAssertNotNil(presenter.editor)
		let full = PersonsGatewaySpy()
		full.fetchPersonsResultToBeReturned = .success((0..<20).map { _ in Person.createPerson() })
		let fullPresenter = PeoplePresenter(configurator: SceneConfigurator(gateway: full), reloadWidgets: {})
		fullPresenter.open(link)
		await fullPresenter.load()
		XCTAssertNil(fullPresenter.editor)
	}

	func testFailedLoadDropsThePendingAddPersonLink() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		presenter.open(URL(string: "growingup-app://\(Constants.widgetAddPersonHost)")!)
		await presenter.load()
		XCTAssertNotNil(presenter.error)
		XCTAssertNil(presenter.editor)
		gateway.fetchPersonsResultToBeReturned = .success(pinnedPeople(count: 2))
		await presenter.load()
		XCTAssertNil(presenter.editor)
	}

	func testExistingEditorTracksEveryFieldAndRevertedDraft() async {
		let gateway = PersonsGatewaySpy()
		var person = Person.createPerson()
		person.birthday = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 2, hour: 15, minute: 8))!
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in XCTFail("Unsaved") })
		await presenter.load()
		XCTAssertFalse(presenter.canSave)
		await presenter.save()
		XCTAssertFalse(gateway.editPersonCalled)
		presenter.name += " draft"
		XCTAssertTrue(presenter.canSave)
		presenter.name = person.name
		XCTAssertFalse(presenter.isDirty)
		presenter.timeOfBirth = person.birthday.addingTimeInterval(60)
		XCTAssertTrue(presenter.canSave)
		presenter.timeOfBirth = person.birthday
		XCTAssertFalse(presenter.isDirty)
		presenter.isOnWidget.toggle()
		XCTAssertTrue(presenter.canSave)
		presenter.isOnWidget = person.isOnWidget
		XCTAssertFalse(presenter.isDirty)
		presenter.celebratesBirthdays.toggle()
		XCTAssertTrue(presenter.canSave)
		presenter.celebratesBirthdays = person.celebratesBirthdays
		XCTAssertFalse(presenter.isDirty)
		presenter.appImage = PersonImage(uiImage: UIImage())
		XCTAssertTrue(presenter.canSave)
		presenter.appImage = PersonImage(id: person.appPicId)
		XCTAssertFalse(presenter.isDirty)
		presenter.widgetImage = PersonImage(uiImage: UIImage())
		XCTAssertTrue(presenter.canSave)
		presenter.widgetImage = PersonImage(id: person.widgetPicId)
		XCTAssertFalse(presenter.isDirty)
	}

	func testRemovingEitherStoredPhotoIsDirtyAndUnsavedDraftDoesNotPersist() async {
		let gateway = PersonsGatewaySpy()
		var person = Person.createPerson()
		person.appPicId = UUID()
		person.widgetPicId = UUID()
		let configurator = SceneConfigurator(gateway: gateway)
		let editor = configurator.editor(person: person, onMutation: { _ in XCTFail("Unsaved") })
		await editor.load()
		editor.appImage = nil
		XCTAssertTrue(editor.canSave)
		editor.appImage = PersonImage(id: person.appPicId)
		XCTAssertFalse(editor.canSave)
		editor.widgetImage = nil
		XCTAssertTrue(editor.canSave)
		editor.name = "Unsaved"
		let reopened = configurator.editor(person: person, onMutation: { _ in })
		await reopened.load()
		XCTAssertEqual(reopened.name, person.name)
		XCTAssertEqual(reopened.appImage?.id, person.appPicId)
		XCTAssertEqual(reopened.widgetImage?.id, person.widgetPicId)
		XCTAssertFalse(reopened.canSave)
		XCTAssertFalse(gateway.editPersonCalled)
	}

	func testBirthdayCelebratesVisibleMidnightAndEveryPageArrivalOnly() {
		let calendar = Calendar.current
		var person = Person.createPerson()
		person.birthday = calendar.date(from: DateComponents(year: 2020, month: 1, day: 16, hour: 6))!
		let midnight = calendar.date(from: DateComponents(year: 2027, month: 1, day: 16))!
		let presenter = OverviewPresenter()
		presenter.tick(person: person, now: midnight.addingTimeInterval(-1), isSelected: true)
		XCTAssertEqual(presenter.celebrationID, 0)
		presenter.tick(person: person, now: midnight, isSelected: true)
		XCTAssertEqual(presenter.celebrationID, 1)
		presenter.tick(person: person, now: midnight.addingTimeInterval(60), isSelected: true)
		XCTAssertEqual(presenter.celebrationID, 1)
		presenter.tick(person: person, now: midnight.addingTimeInterval(120), isSelected: false)
		XCTAssertEqual(presenter.celebrationID, 1)
		presenter.tick(person: person, now: midnight.addingTimeInterval(180), isSelected: true)
		XCTAssertEqual(presenter.celebrationID, 2)
		let offscreen = OverviewPresenter()
		offscreen.tick(person: person, now: midnight.addingTimeInterval(-1), isSelected: false)
		offscreen.tick(person: person, now: midnight, isSelected: false)
		XCTAssertEqual(offscreen.celebrationID, 0)
	}

}
