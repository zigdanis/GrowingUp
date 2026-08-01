//
//  DisplayPersonsUseCaseTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import XCTest

@testable import Core
@testable import GrowingUp

class FetchPersonsUseCaseTests: XCTestCase {

	var sut: FetchPersonsUseCaseImplementation!
	let gatewaySpy = PersonsGatewaySpy()

	override func setUp() {
		sut = FetchPersonsUseCaseImplementation(personsGateway: gatewaySpy)
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

	func testAsyncFetchPropagatesError() async {
		gatewaySpy.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)

		do {
			_ = try await sut.fetchPersons()
			XCTFail("Expected fetch failure")
		} catch {
			XCTAssertEqual(error as? CoreError, .coreDataFetchFailed)
		}
	}
}
