//
//  CoreDataPersonsGatewayTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import CoreData
import XCTest

@testable import Core
@testable import GrowingUp

class CoreDataPersonsGatewayTests: XCTestCase {

	// https://www.martinfowler.com/bliki/TestDouble.html
	var inMemoryCoreDataStack = InMemoryCoreDataStack()
	var managedObjectContextSpy = NSManagedObjectContextSpy()
	var inMemoryCoreDataGateway: CoreDataPersonsGateway {
		return CoreDataPersonsGateway(coreDataStack: inMemoryCoreDataStack)
	}

	func test_SUT_AddPersonWithParameters_Succeed() async throws {
		let addPersonParameters = AddPersonParameters.createParameters()

		let person = try await inMemoryCoreDataGateway.add(parameters: addPersonParameters)

		assert(person: person, builtFromParameters: addPersonParameters)
	}

	func test_SUT_EditPerson_ShouldSucceedWithCorrectParameters() async throws {
		// Given
		let cdPerson = inMemoryCoreDataStack.fakeEntity(withType: CoreDataPerson.self)
		cdPerson.id = UUID().uuidString
		cdPerson.createdDate = Date()
		cdPerson.birthdate = Date()
		inMemoryCoreDataStack.saveContext()
		var editParams = AddPersonParameters.createParameters()
		editParams.name = "John Snow"
		editParams.isOnWidget = true
		editParams.dayOfBirth = Date().addingTimeInterval(-60 * 60 * 24 * 365 * 10)
		editParams.timeOfBirth = Date().addingTimeInterval(-60)

		let person = try await inMemoryCoreDataGateway.edit(person: cdPerson.person, with: editParams)

		assert(person: person, builtFromParameters: editParams)
	}

	func test_SUT_RemovePerson_ShouldSucceed() async throws {
		// Given
		let cdPerson = inMemoryCoreDataStack.fakeEntity(withType: CoreDataPerson.self)
		cdPerson.id = UUID().uuidString
		cdPerson.createdDate = Date()
		cdPerson.birthdate = Date()
		inMemoryCoreDataStack.saveContext()

		try await inMemoryCoreDataGateway.remove(person: cdPerson.person)
	}

	func test_SUT_FetchPersons_ShouldSucceed() async throws {
		_ = try await inMemoryCoreDataGateway.fetchPersons()
	}

	func test_Widget_AllowsSixPeopleAndUnpinningFreesASlot() async throws {
		let gateway = inMemoryCoreDataGateway
		for _ in 0..<6 {
			_ = try await gateway.add(parameters: .createParameters())
		}
		let pinnedPeople = try await gateway.fetchWidgetPersons()
		XCTAssertEqual(pinnedPeople.count, 6)

		do {
			_ = try await gateway.add(parameters: .createParameters())
			XCTFail("A seventh person must not be pinned")
		} catch {
			XCTAssertEqual(error as? CoreError, .widgetPeopleLimitReached)
		}
		let peopleAfterFailure = try await gateway.fetchPersons()
		let pinnedPeopleAfterFailure = try await gateway.fetchWidgetPersons()
		XCTAssertEqual(peopleAfterFailure, pinnedPeople)
		XCTAssertEqual(pinnedPeopleAfterFailure, pinnedPeople)

		var unpinParameters = AddPersonParameters.createParameters()
		unpinParameters.isOnWidget = false
		_ = try await gateway.edit(person: XCTUnwrap(pinnedPeople.first), with: unpinParameters)
		let replacement = try await gateway.add(parameters: .createParameters())
		let finalPinnedPeople = try await gateway.fetchWidgetPersons()
		XCTAssertEqual(finalPinnedPeople.count, 6)
		XCTAssertTrue(finalPinnedPeople.contains(replacement))
	}

	func test_Widget_FailedSeventhPinPreservesTheExistingPerson() async throws {
		let gateway = inMemoryCoreDataGateway
		for _ in 0..<6 {
			_ = try await gateway.add(parameters: .createParameters())
		}
		var parameters = AddPersonParameters.createParameters()
		parameters.isOnWidget = false
		let unpinnedPerson = try await gateway.add(parameters: parameters)
		let peopleBeforeEdit = try await gateway.fetchPersons()
		parameters.isOnWidget = true
		parameters.name = "Changed name"

		do {
			_ = try await gateway.edit(person: unpinnedPerson, with: parameters)
			XCTFail("A seventh person must not be pinned")
		} catch {
			XCTAssertEqual(error as? CoreError, .widgetPeopleLimitReached)
		}

		let peopleAfterFailure = try await gateway.fetchPersons()
		let pinnedPeople = try await gateway.fetchWidgetPersons()
		XCTAssertEqual(peopleAfterFailure, peopleBeforeEdit)
		XCTAssertEqual(pinnedPeople.count, 6)
	}

	func test_Widget_ModelUpgradePreservesPeopleAndPhotoIdentifiers() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let storeURL = directory.appendingPathComponent("GrowingUp.sqlite")
		let bundle = try XCTUnwrap(Bundle(identifier: Constants.bundleIdentifier))
		let modelURL = try XCTUnwrap(bundle.url(forResource: "GrowingUp", withExtension: "momd"))
		let originalModel = try XCTUnwrap(
			NSManagedObjectModel(contentsOf: modelURL.appendingPathComponent("GrowingUp.mom")))
		let currentModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
		let originalContainer = try loadContainer(model: originalModel, storeURL: storeURL)
		var originalPeople: [Person] = []
		try originalContainer.viewContext.performAndWait {
			let access = try AccessToWidget.sharedInstance(in: originalContainer.viewContext)
			for index in 0..<4 {
				let person = CoreDataPerson(context: originalContainer.viewContext)
				person.name = "Person \(index)"
				person.birthdate = Date(timeIntervalSince1970: Double(index) * 86400)
				person.createdDate = Date(timeIntervalSince1970: Double(index) * 60)
				person.appPicId = UUID().uuidString
				person.widgetPicId = UUID().uuidString
				person.accessToWidget = index < 3 ? access : nil
				originalPeople.append(person.person)
			}
			try originalContainer.viewContext.save()
		}
		try closeContainer(originalContainer)
		let originalMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
			ofType: NSSQLiteStoreType, at: storeURL)
		XCTAssertFalse(currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: originalMetadata))

		let upgradedContainer = try loadContainer(model: currentModel, storeURL: storeURL)
		defer { try? closeContainer(upgradedContainer) }
		try upgradedContainer.viewContext.performAndWait {
			let request = CoreDataPerson.fetchRequest()
			request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
			let upgradedPeople = try upgradedContainer.viewContext.fetch(request).map(\.person)
			XCTAssertEqual(upgradedPeople, originalPeople)
		}
		let upgradedMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
			ofType: NSSQLiteStoreType, at: storeURL)
		XCTAssertTrue(currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: upgradedMetadata))
	}

	private func loadContainer(model: NSManagedObjectModel, storeURL: URL) throws -> NSPersistentContainer {
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		let description = NSPersistentStoreDescription(url: storeURL)
		description.shouldAddStoreAsynchronously = false
		container.persistentStoreDescriptions = [description]
		var loadingError: Error?
		container.loadPersistentStores { _, error in loadingError = error }
		if let loadingError {
			throw loadingError
		}
		return container
	}

	private func closeContainer(_ container: NSPersistentContainer) throws {
		container.viewContext.performAndWait { container.viewContext.reset() }
		for store in container.persistentStoreCoordinator.persistentStores {
			try container.persistentStoreCoordinator.remove(store)
		}
	}

}

private func assert(
	person: Person, builtFromParameters parameters: AddPersonParameters, file: StaticString = #file, line: UInt = #line
) {
	XCTAssertEqual(person.name, parameters.name, "name mismatch", file: file, line: line)
	XCTAssertEqual(
		person.birthday.timeIntervalSince1970, parameters.combinedDate().timeIntervalSince1970, "birthday mismatch",
		file: file, line: line)
	XCTAssertEqual(person.appPicId, parameters.appImage?.id, "app pic mismatch", file: file, line: line)
	XCTAssertEqual(person.widgetPicId, parameters.widgetImage?.id, "widget pic mismatch", file: file, line: line)
	XCTAssertEqual(person.isOnWidget, parameters.isOnWidget, "fav state mismatch", file: file, line: line)
}
