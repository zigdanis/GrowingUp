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
	let coreDataGatewaySpy = CoreDataPersonsGatewaySpy()
	let taskManagerSpy = TaskManagerSpy()

    override func setUp() {
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManagerSpy)
    }

	func test_SUT_WhenAddingPerson_CallingTaskManager() {
		// Given
		let params = AddPersonParameters.createParameters()
		let expectedValue = Person.createPerson()
		taskManagerSpy.expectedResultValue = expectedValue
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
		let savedPerson = expectation(description: "Expecting to save Person")
		// When
		sut.add(parameters: params) { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.addWithContextCalled, "Epected to call saving person to CoreData with specified managed object context in background")
			savedPerson.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenFetchingPersons_CallingTaskManagerWithExpectedResult() {
		// Given
		let expectedValue = [Person.createPerson()]
		taskManagerSpy.expectedResultValue = expectedValue
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
		let workIsDone = expectation(description: "Expecting to finish fetching")
		// When
		sut.fetchPersons { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.fetchWithContextCalled, "Epected to call fetching persons from CoreData")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}
}
