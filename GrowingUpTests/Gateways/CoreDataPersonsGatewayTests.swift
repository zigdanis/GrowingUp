//
//  CoreDataPersonsGatewayTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

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
