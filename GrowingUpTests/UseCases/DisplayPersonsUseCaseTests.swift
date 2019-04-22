//
//  DisplayPersonsUseCaseTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

class DisplayPersonsUseCaseTests: XCTestCase {

	var sut: DisplayPersonsUseCaseImplementation!
	let gatewaySpy = PersonsGatewaySpy()

    override func setUp() {
		sut = DisplayPersonsUseCaseImplementation(personsGateway: gatewaySpy)
    }

	func test_SUT_WhenFetchPersons_CallingGatewayAndCompletion() {
		// Given
		let persons = [Person.createPerson()]
		let expectedResult: Result<[Person], CoreError> = .success(persons)
		gatewaySpy.fetchPersonsResultToBeReturned = expectedResult
		let workIsDone = expectation(description: "Expecting to finish fetching PersonsGateway")
		// When
		sut.fetchPersons { result in
			// Then
			XCTAssertTrue(self.gatewaySpy.fetchPersonsCalled, "Expected to receive fetchPersons call in PersonsGateway")
			XCTAssertEqual(result, expectedResult, "Expected to get fetched persons")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenFailedToFetchPersons_CallingCompletioWithError() {
		// Given
		let expectedResult: Result<[Person], CoreError> = .failure(CoreError.coreDataFetchFailed)
		gatewaySpy.fetchPersonsResultToBeReturned = expectedResult
		let workIsDone = expectation(description: "Expecting to finish fetching PersonsGateway")
		// When
		sut.fetchPersons { result in
			// Then
			XCTAssertTrue(self.gatewaySpy.fetchPersonsCalled, "Expected to receive fetchPersons call in PersonsGateway")
			XCTAssertEqual(result, expectedResult, "Expected to get fetched persons")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}
}
