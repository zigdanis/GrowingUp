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
		cdPerson.floatingBirthdate = Date()
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
		cdPerson.floatingBirthdate = Date()
		inMemoryCoreDataStack.saveContext()

		try await inMemoryCoreDataGateway.remove(person: cdPerson.person)
	}

	func test_SUT_FetchPersons_ShouldSucceed() async throws {
		_ = try await inMemoryCoreDataGateway.fetchPersons()
	}

	func test_CelebratesBirthdays_DefaultsToTrueAndRoundTrips() async throws {
		XCTAssertTrue(inMemoryCoreDataStack.fakeEntity(withType: CoreDataPerson.self).celebratesBirthdays)
		inMemoryCoreDataStack.persistentContainer.viewContext.rollback()
		let gateway = inMemoryCoreDataGateway
		var parameters = AddPersonParameters.createParameters()
		XCTAssertTrue(parameters.celebratesBirthdays)
		let added = try await gateway.add(parameters: parameters)
		XCTAssertTrue(added.celebratesBirthdays)

		parameters.celebratesBirthdays = false
		let edited = try await gateway.edit(person: added, with: parameters)
		XCTAssertFalse(edited.celebratesBirthdays)
		let fetchedAfterOptOut = try await gateway.fetchPersons()
		XCTAssertEqual(fetchedAfterOptOut.map(\.celebratesBirthdays), [false])

		parameters.celebratesBirthdays = true
		_ = try await gateway.edit(person: edited, with: parameters)
		let fetchedAfterOptIn = try await gateway.fetchPersons()
		XCTAssertEqual(fetchedAfterOptIn.map(\.celebratesBirthdays), [true])
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
		try assertUpgradePreservesPeople(fromModel: "GrowingUp.mom")
	}

	func test_CelebrationsUpgradeKeepsExistingPeopleCelebrating() throws {
		try assertUpgradePreservesPeople(fromModel: "GrowingUpSixPeople.mom")
	}

	func test_FloatingBirthdatesUpgradePreservesPeople() throws {
		try assertUpgradePreservesPeople(fromModel: "GrowingUpCelebrations.mom")
	}

	/// An upgrade pins each saved birthday to the day and time it shows at that moment, which then survive travel.
	func test_FloatingBirthdatesUpgradeKeepsBirthdaysOnTheirDayAfterTravel() throws {
		let systemTimeZone = NSTimeZone.default
		defer { NSTimeZone.default = systemTimeZone }
		NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "Europe/Moscow"))
		let moscow = Calendar.current
		let birthdates = [
			DateComponents(year: 2020, month: 5, day: 10), DateComponents(year: 2020, month: 2, day: 29, hour: 23, minute: 50)
		].map { moscow.date(from: $0)! }
		let storeURL = try makeStoreURL()
		defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
		let originalContainer = try loadOriginalContainer(model: try model(named: "GrowingUpCelebrations.mom"), storeURL: storeURL)
		try originalContainer.viewContext.performAndWait {
			for (index, birthdate) in birthdates.enumerated() {
				let person = CoreDataPerson(context: originalContainer.viewContext)
				person.birthdate = birthdate
				person.createdDate = Date(timeIntervalSince1970: Double(index))
			}
			try originalContainer.viewContext.save()
		}
		try closeContainer(originalContainer)

		let upgradedContainer = try loadContainer(model: try model(named: nil), storeURL: storeURL)
		defer { try? closeContainer(upgradedContainer) }
		NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
		let newYork = Calendar.current
		try upgradedContainer.viewContext.performAndWait {
			let request = CoreDataPerson.fetchRequest()
			request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
			let people = try upgradedContainer.viewContext.fetch(request)
			var utc = Calendar(identifier: .gregorian)
			utc.timeZone = .gmt
			XCTAssertEqual(
				people.map(\.floatingBirthdate),
				[DateComponents(year: 2020, month: 5, day: 10), DateComponents(year: 2020, month: 2, day: 29, hour: 23, minute: 50)]
					.map { utc.date(from: $0) })
			let readings = people.map { person in
				([.year, .month, .day, .hour, .minute] as [Calendar.Component]).map { newYork.component($0, from: person.person.birthday) }
			}
			XCTAssertEqual(readings, [[2020, 5, 10, 0, 0], [2020, 2, 29, 23, 50]])
		}
	}

	/// Lightweight migration from `fromModel` keeps people, pins and photos, and defaults celebrations to on.
	private func assertUpgradePreservesPeople(fromModel modelName: String) throws {
		let storeURL = try makeStoreURL()
		defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
		let originalModel = try model(named: modelName)
		let currentModel = try model(named: nil)
		let originalContainer = try loadOriginalContainer(model: originalModel, storeURL: storeURL)
		var originalPeople: [Person] = []
		try originalContainer.viewContext.performAndWait {
			let access = try AccessToWidget.sharedInstance(in: originalContainer.viewContext)
			for index in 0..<4 {
				let person = CoreDataPerson(context: originalContainer.viewContext)
				person.name = "Person \(index)"
				let birthdate = Date(timeIntervalSince1970: Double(index) * 86400)
				person.birthdate = birthdate
				person.createdDate = Date(timeIntervalSince1970: Double(index) * 60)
				person.appPicId = UUID().uuidString
				person.widgetPicId = UUID().uuidString
				person.accessToWidget = index < 3 ? access : nil
				// Older models have no celebration flag, so build the expected person without reading it.
				originalPeople.append(
					Person(
						id: try XCTUnwrap(UUID(string: person.id)), name: person.name ?? "", floatingBirthdate: Person.floatingBirthdate(of: birthdate),
						appPicId: UUID(string: person.appPicId), widgetPicId: UUID(string: person.widgetPicId), isOnWidget: index < 3,
						createdDate: person.createdDate))
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

	private func makeStoreURL() throws -> URL {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		return directory.appendingPathComponent("GrowingUp.sqlite")
	}

	/// The model version `name` in the compiled model, or the current version for `nil`.
	private func model(named name: String?) throws -> NSManagedObjectModel {
		let bundle = try XCTUnwrap(Bundle(identifier: Constants.bundleIdentifier))
		let modelURL = try XCTUnwrap(bundle.url(forResource: "GrowingUp", withExtension: "momd"))
		return try XCTUnwrap(NSManagedObjectModel(contentsOf: name.map { modelURL.appendingPathComponent($0) } ?? modelURL))
	}

	/// Opens a store with an earlier model the way that version did, without pinning birthdates it has no attribute for.
	private func loadOriginalContainer(model: NSManagedObjectModel, storeURL: URL) throws -> NSPersistentContainer {
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
		try CoreDataStackImplementation.loadPersistentStores(container)
		return container
	}

	private func loadContainer(model: NSManagedObjectModel, storeURL: URL) throws -> NSPersistentContainer {
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		let description = NSPersistentStoreDescription(url: storeURL)
		description.shouldAddStoreAsynchronously = false
		container.persistentStoreDescriptions = [description]
		let stack = CoreDataStackImplementation(makeContainer: { container })
		return try stack.persistentContainer
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
	XCTAssertEqual(person.celebratesBirthdays, parameters.celebratesBirthdays, "celebration mismatch", file: file, line: line)
}
