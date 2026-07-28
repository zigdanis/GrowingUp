//
//  RemovePersonUseCaseTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 24/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import XCTest

@testable import Core

class RemovePersonUseCaseTests: XCTestCase {

	var sut: RemovePersonUseCaseImplementation!
	let personsGatewaySpy = PersonsGatewaySpy()

	override func setUp() {
		sut = RemovePersonUseCaseImplementation(personsGateway: personsGatewaySpy)
	}

	func test_SUT_WhenRemovingPerson_CallsPersonsGatewayAndCallsCompletion() {
		// Given
		let personToDelete = Person.createPerson()
		let expectedResultToBeReturned: Result<Void, CoreError> = .success(())
		personsGatewaySpy.removePersonResultToBeReturned = expectedResultToBeReturned
		let removePersonExpectation = expectation(description: "Remove Person expectation")
		// When
		sut.remove(person: personToDelete) { result in
			// Then
			assertOk(result, "Expected to receive success remove person result")
			XCTAssertTrue(self.personsGatewaySpy.removePersonCalled, "Expected to call Persons Gateway")
			removePersonExpectation.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}

	func test_SUT_WhenRemovingPersonFailed_CallsCompletionHandler() {
		// Given
		let personToDelete = Person.createPerson()
		let expectedError = CoreError(message: "Some Errror")
		personsGatewaySpy.removePersonResultToBeReturned = .failure(expectedError)
		let removePersonExpectation = expectation(description: "Remove Person expectation")
		// When
		sut.remove(person: personToDelete) { result in
			// Then
			do {
				try result.get()
			} catch {
				XCTAssertEqual(error as? CoreError, expectedError, "Expected to call completion with specified error")
			}
			removePersonExpectation.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}
}

func assertOk<T>(_ result: Result<T, CoreError>, _ message: String) {
	XCTAssertNoThrow(try result.get(), message)
}
