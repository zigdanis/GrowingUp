//
//  EditPersonUseCaseTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 16/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import XCTest

@testable import Core
@testable import GrowingUp

class AddPersonUseCaseTests: XCTestCase {

	var sut: AddPersonUseCaseImplementation!
	let personsGatewaySpy = PersonsGatewaySpy()

	override func setUp() {
		super.setUp()
		sut = AddPersonUseCaseImplementation(personsGateway: personsGatewaySpy)
	}

	func test_SUT_AddPerson_PassingParamsToPersonsGatewayAndCallsCompletionHandler() {
		// Given
		let params = AddPersonParameters.createParameters()
		let expectedResultToBeReturned: Result<Person, CoreError> = .success(Person.createPerson())
		personsGatewaySpy.addPersonResultToBeReturned = expectedResultToBeReturned
		let addPersonExpectation = expectation(description: "Add Person Expectation")
		// When
		sut.add(parameters: params) { result in
			// Then
			XCTAssertEqual(
				self.personsGatewaySpy.addPersonParameters, params,
				"Should have been call PersonsGateway AddPerson method with specified params")

			XCTAssertEqual(expectedResultToBeReturned, result, "Completion handler didn't return expected result")
			addPersonExpectation.fulfill()
		}
		waitForExpectations(timeout: 1, handler: nil)
	}

	func test_SUT_AddPersonFail_CallsCompletionHandler() {
		// Given
		let params = AddPersonParameters.createParameters()
		let expectedResultToBeReturned: Result<Person, CoreError> = .failure(CoreError(message: "Some Error"))
		personsGatewaySpy.addPersonResultToBeReturned = expectedResultToBeReturned
		let addPersonExpectation = expectation(description: "Add Person Expectation")
		// When
		sut.add(parameters: params) { result in
			// Then
			XCTAssertEqual(
				self.personsGatewaySpy.addPersonParameters, params,
				"Should have been call PersonsGateway AddPerson method with specified params")
			XCTAssertEqual(expectedResultToBeReturned, result, "Completion handler didn'w return expected result")
			addPersonExpectation.fulfill()
		}
		waitForExpectations(timeout: 1, handler: nil)
	}

	func testAsyncAddReturnsPerson() async throws {
		let parameters = AddPersonParameters.createParameters()
		let expectedPerson = Person.createPerson()
		personsGatewaySpy.addPersonResultToBeReturned = .success(expectedPerson)

		let person = try await sut.add(parameters: parameters)

		XCTAssertEqual(person, expectedPerson)
		XCTAssertEqual(personsGatewaySpy.addPersonParameters, parameters)
	}
}
