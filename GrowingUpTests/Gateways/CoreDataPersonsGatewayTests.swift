//
//  CoreDataPersonsGatewayTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

// Discussion:
// Happy path is tested using an in memory core data stack while the error paths are "simulated" using a stub NSManagedObjectContextStub
// Probably you could use NSManagedObjectContextStub for happy path testing as well, however you might not be able to instantiate a NSManagedObject subclass
// without a valid context
class CoreDataPersonsGatewayTests: XCTestCase {

    // https://www.martinfowler.com/bliki/TestDouble.html
    var inMemoryCoreDataStack = InMemoryCoreDataStack()
    var managedObjectContextSpy = NSManagedObjectContextSpy()
    var inMemoryCoreDataGateway: CoreDataPersonsGateway {
        return CoreDataPersonsGatewayImplementation(viewContext: inMemoryCoreDataStack.persistentContainer.viewContext)
    }
    var errorPathCoreDataGateway: CoreDataPersonsGateway {
        return CoreDataPersonsGatewayImplementation(viewContext: managedObjectContextSpy)
    }

    func test_SUT_AddPersonWithParameters_Succeed() {

        // Given
        let addPersonParameters = AddPersonParameters.createParameters()
        let addPersonCompletionHandlerExpectation = expectation(description: "Add person completion handler expectation")

        // When
        inMemoryCoreDataGateway.add(parameters: addPersonParameters) { (result) in
            // Then
            guard let person = try? result.get() else {
                return XCTFail("Should've saved the person with success")
            }
            assert(person: person, builtFromParameters: addPersonParameters)
            addPersonCompletionHandlerExpectation.fulfill()
        }

        // Exit
        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_SUT_AddPersonWithParameters_FailsWhenSaving() {

        // Given
		let expectedErrorToThrow = CoreError(message: "Some core data error")
        let expectedResultToBeReturned: Result<Person, CoreError> = .failure(expectedErrorToThrow)
        let addedCoreDataPerson = inMemoryCoreDataStack.fakeEntity(withType: CoreDataPerson.self)
        managedObjectContextSpy.addEntityToReturn = addedCoreDataPerson
        managedObjectContextSpy.saveErrorToReturn = expectedErrorToThrow
        let addPersonCompletionHandlerExpectation = expectation(description: "Add Person completion handler expectation")

        // When
        errorPathCoreDataGateway.add(parameters: AddPersonParameters.createParameters()) { (result) in
            // Then
            XCTAssertEqual(expectedResultToBeReturned, result, "Failure error wasn't returned")
            XCTAssertTrue(self.managedObjectContextSpy.deletedObject! === addedCoreDataPerson, "The inserted entity should've been deleted")
            addPersonCompletionHandlerExpectation.fulfill()
        }

        // Exit
        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_SUT_AddWithParameters_FailsWithoutReachingSave() {

        // Given
        let expectedResultToBeReturned: Result<Person, CoreError> = .failure(CoreError.coreDataAddFailed)
        managedObjectContextSpy.addEntityToReturn = nil
        let addPersonCompletionHandlerExpectation = expectation(description: "Add person completion handler expectation")

        // When
        errorPathCoreDataGateway.add(parameters: AddPersonParameters.createParameters()) { (result) in
            // Then
            XCTAssertEqual(expectedResultToBeReturned, result, "Failure error wasn't returned")
            addPersonCompletionHandlerExpectation.fulfill()
        }

        // Exit
        waitForExpectations(timeout: 1, handler: nil)
    }

	func test_SUT_FetchPersons_ShouldSucceed() {
		// Given
		let workIsDone = expectation(description: "Fetch persons completion handler expectation")
		// When
		inMemoryCoreDataGateway.fetchPersons { result in
			// Then
			switch result {
			case .failure: XCTFail("Should've fetched persons with success")
			default: ()
			}
			workIsDone.fulfill()
		}
		// Exit
		waitForExpectations(timeout: 0.1, handler: nil)
	}

	func test_SUT_FetchPersons_FailsWhenSaving() {
		// Given
		let errorToThrow = CoreError(message: "Some core data error")
		let expectedResult: Result<[Person], CoreError> = .failure(errorToThrow)
		managedObjectContextSpy.fetchErrorToThrow = errorToThrow
		let workIsDone = expectation(description: "Fetch Persons completion handler expectation")
		// When
		errorPathCoreDataGateway.fetchPersons { result in
			XCTAssertEqual(result, expectedResult, "Failure error wasn't returned")
			workIsDone.fulfill()
		}
		// Exit
		waitForExpectations(timeout: 0.1, handler: nil)
	}

}

private func assert(person: Person, builtFromParameters parameters: AddPersonParameters, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(person.name, parameters.name, "name mismatch", file: file, line: line)
    XCTAssertEqual(person.birthday.timeIntervalSince1970, parameters.combinedDate()?.timeIntervalSince1970, "birthday mismatch", file: file, line: line)
}
