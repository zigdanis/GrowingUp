//
//  AddPersonUseCaseTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 16/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
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
        let expectedResultToBeReturned: Result<Person> = .success(Person.createPerson())
        personsGatewaySpy.addPersonResultToBeReturned = expectedResultToBeReturned
        let addPersonExpectation = expectation(description: "Add Person Expectation")
        // When
        sut.add(parameters: params) { result in
            // Then
            XCTAssertEqual(self.personsGatewaySpy.addPersonParameters, params, "Should have been call PersonsGateway AddPerson method with specified params")
            XCTAssertEqual(expectedResultToBeReturned, result, "Completion handler didn't return expected result")
            addPersonExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func test_SUT_AddPersonFail_CallsCompletionHandler() {
        // Given
        let params = AddPersonParameters.createParameters()
        let expectedResultToBeReturned: Result<Person> = .failure(CoreError(message: "Some Error"))
        personsGatewaySpy.addPersonResultToBeReturned = expectedResultToBeReturned
        let addPersonExpectation = expectation(description: "Add Person Expectation")
        // When
        sut.add(parameters: params) { result in
            XCTAssertEqual(self.personsGatewaySpy.addPersonParameters, params, "Should have been call PersonsGateway AddPerson method with specified params")
            XCTAssertEqual(expectedResultToBeReturned, result, "Completion handler didn'w return expected result")
            addPersonExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}
