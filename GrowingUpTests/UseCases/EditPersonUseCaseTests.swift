//
//  EditPersonUseCaseTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 24/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest

@testable import Core

class EditPersonUseCaseTests: XCTestCase {

	var sut: EditPersonUseCaseImplementation!
	let personsGatewaySpy = PersonsGatewaySpy()

	override func setUp() {
		sut = EditPersonUseCaseImplementation(personsGateway: personsGatewaySpy)
	}

	func test_SUT_EditPersonWithParams_PassingParamsToGatewayAndCallsCompletionHandler() {
		// Given
		let personToEdit = Person.createPerson()
		let params = AddPersonParameters.createParameters()
		let expectedResultToBeReturned: Result<Person, CoreError> = .success(Person.createPerson())
		personsGatewaySpy.editPersonResultToBeReturned = expectedResultToBeReturned
		let editPersonExpectation = expectation(description: "Edit Person expectation")
		// When
		sut.edit(person: personToEdit, with: params) { result in
			// Then
			XCTAssertEqual(
				self.personsGatewaySpy.addPersonParameters, params,
				"Should have been called Edit Person with provided parameters")
			XCTAssertEqual(expectedResultToBeReturned, result, "Expected to receive success edited person result")
			editPersonExpectation.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}

	func test_SUT_EditPersonFaile_CallsCompletionHandler() {
		// Given
		let personToEdit = Person.createPerson()
		let params = AddPersonParameters.createParameters()
		let expectedResultToBeReturned: Result<Person, CoreError> = .failure(CoreError(message: "Some Edit failed error"))
		personsGatewaySpy.editPersonResultToBeReturned = expectedResultToBeReturned
		let editPersonExpectation = expectation(description: "Edit Person expectation")
		// When
		sut.edit(person: personToEdit, with: params) { result in
			// Then
			XCTAssertEqual(
				self.personsGatewaySpy.addPersonParameters, params,
				"Should have been called Edit Person with provided parameters")
			XCTAssertEqual(expectedResultToBeReturned, result, "Expected to receive failure of editing person result")
			editPersonExpectation.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}
}
