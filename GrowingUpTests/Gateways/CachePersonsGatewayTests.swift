//
//  CachePersonsGatewayTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

class CachePersonsGatewayTests: XCTestCase {

	var sut: CachePersonsGateway!
	let coreDataGatewaySpy = PersonsGatewaySpy()
	let taskManagerSpy = TaskManagerSpy()

    override func setUp() {
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManagerSpy)
    }

	func test_SUT_WhenAddingPerson_CallingTaskManager() {
		// Given
		let params = AddPersonParameters.createParameters()
		let expectedValue = Person.createPerson()
		taskManagerSpy.expectedResultValue = expectedValue
		let addPersonCallback = Result<Person, CoreError>.success(Person.createPerson())
		coreDataGatewaySpy.addPersonResultToBeReturned = addPersonCallback
		let savedPerson = expectation(description: "Expecting to save Person")
		// When
		sut.add(parameters: params) { result in
			// Then
			XCTAssertEqual(result, .success(expectedValue), "Expected to receive saved Person")
			XCTAssertTrue(self.taskManagerSpy.processTasksCalled, "Expected to call TaskManager")
			savedPerson.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenAddingPerson_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		let params = AddPersonParameters.createParameters()
		let addPersonCallback = Result<Person, CoreError>.success(Person.createPerson())
		coreDataGatewaySpy.addPersonResultToBeReturned = addPersonCallback
		let savedPerson = expectation(description: "Expecting to save Person")
		// When
		sut.add(parameters: params) { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.addPersonCalled, "Epected to call saving person to CoreData with specified managed object context in background")
			savedPerson.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenEditingPersons_CallingTaskManagerWithExpectedResult() {
		// Given
		let expectedPerson = Person.createPerson()
		let params = AddPersonParameters.createParameters()
		taskManagerSpy.expectedResultValue = expectedPerson
		let editPersonCallback = Result<Person, CoreError>.success(Person.createPerson())
		coreDataGatewaySpy.editPersonResultToBeReturned = editPersonCallback
		let workIsDone = expectation(description: "Expecting to edit Person")
		// When
		sut.edit(person: Person.createPerson(), with: params) { result in
			// Then
			XCTAssertEqual(result, .success(expectedPerson), "Expected to receive edited Person")
			XCTAssertTrue(self.taskManagerSpy.processTasksCalled, "Expected to call TaskManager")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenEditingPersons_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		let editPersonCallback = Result<Person, CoreError>.success(Person.createPerson())
		coreDataGatewaySpy.editPersonResultToBeReturned = editPersonCallback
		let workIsDone = expectation(description: "Expecting to finish editing")
		// When
		sut.edit(person: Person.createPerson(), with: AddPersonParameters.createParameters(), completionHandler: { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.editPersonCalled, "Epected to call Edit Person from CoreData")
			workIsDone.fulfill()
		})
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenRemovingPersons_CallingTaskManagerWithExpectedResult() {
		// Given
		taskManagerSpy.expectedResultValue = ()
		coreDataGatewaySpy.removePersonResultToBeReturned = .success(())
		let workIsDone = expectation(description: "Expecting to Remove Person")
		// When
		sut.remove(person: Person.createPerson()) { result in
			// Then
			switch result {
			case .success: ()
			case .failure(let error):
				XCTFail("Expected to Remove Person but got error = \(error.localizedDescription)")
			}
			XCTAssertTrue(self.taskManagerSpy.processTasksCalled, "Expected to call TaskManager")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenRemovingPersons_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		coreDataGatewaySpy.removePersonResultToBeReturned = .success(())
		let workIsDone = expectation(description: "Expecting to finish removing")
		// When
		sut.remove(person: Person.createPerson(), completionHandler: { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.removePersonCalled, "Epected to call Remove Person from CoreData")
			workIsDone.fulfill()
		})
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenFetchingPersons_CallingTaskManagerWithExpectedResult() {
		// Given
		let expectedValue = [Person.createPerson()]
		taskManagerSpy.expectedResultValue = expectedValue
		coreDataGatewaySpy.fetchPersonsResultToBeReturned = .success([])
		let workIsDone = expectation(description: "Expecting to fetch Persons")
		// When
		sut.fetchPersons { result in
			// Then
			XCTAssertEqual(result, .success(expectedValue), "Expected to receive array of Persons")
			XCTAssertTrue(self.taskManagerSpy.processTasksCalled, "Expected to call TaskManager")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenFetchingPersons_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		coreDataGatewaySpy.fetchPersonsResultToBeReturned = .success([])
		let workIsDone = expectation(description: "Expecting to finish fetching")
		// When
		sut.fetchPersons { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.fetchPersonsCalled, "Epected to call fetching persons from CoreData")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}
}
