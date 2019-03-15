//
//  AddPersonPresenterTests.swift
//  AgingTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import Aging

class AddPersonPresenterTests: XCTestCase {
    
    // https://www.martinfowler.com/bliki/TestDouble.html
    let addPersonViewSpy = AddPersonViewSpy()
    let addPersonUseCaseSpy = AddPersonUseCaseSpy()
    let addPersonViewRouterSpy = AddPersonViewRouterSpy()
    let addPersonPresenterDelegateSpy = AddPersonPresenterDelegateSpy()
    var sut: AddPersonPresenterImplementation!
    
    // MARK: - Set up
    
    override func setUp() {
        super.setUp()
        sut = AddPersonPresenterImplementation(view: addPersonViewSpy, addPersonUseCase: addPersonUseCaseSpy, router: addPersonViewRouterSpy, delegate: addPersonPresenterDelegateSpy)
    }
    
    func test_SUT_AddButtonPressed_DismissView() {
        // Given
        let params = AddPersonParameters.createParameters()
        addPersonUseCaseSpy.resultToBeReturned = .success(Person.createPerson())
        // When
        sut.addButtonPressed(parameters: params)
        // Then
        XCTAssertTrue(addPersonViewRouterSpy.dismissCalled, "Expected to dismiss view after saved person")
    }
    
    func test_SUT_AddButtonPressed_AddAndCancelButtonsDisabledBeforeCompletionHandler() {
        // Given
        let params = AddPersonParameters.createParameters()
        addPersonUseCaseSpy.callCompletionHandlerImmediate = false
        // When
        sut.addButtonPressed(parameters: params)
        // Then
        XCTAssertFalse(addPersonViewSpy.addButtonEnabledState ?? true, "Add button should've been set to disabled")
        XCTAssertFalse(addPersonViewSpy.cancelButtonEnabledState ?? true, "Cancel button should've been set to disabled")
    }
    
    func test_SUT_AddButtonPressed_ShouldSavePerson() {
        // Given
        let params = AddPersonParameters.createParameters()
        addPersonUseCaseSpy.resultToBeReturned = .success(Person.createPerson())
        // When
        sut.addButtonPressed(parameters: params)
        // Then
        guard let expectedParameters = addPersonUseCaseSpy.personToAddParameters else {
            return XCTFail("Expected to get AddPersonParameters from AddPersonUseCase")
        }
        XCTAssertEqual(expectedParameters, params, "Should have been called addPerson for AddPersonUseCase")
    }
    
    func test_SUT_CancelButtonPressed_DismissView() {
        // When
        sut.cancelButtonPressed()
        // Then
        XCTAssertTrue(addPersonViewRouterSpy.dismissCalled, "Should have been called dismiss on cancel tap")
    }
    
    func test_SUT_AddButtonPressedWithError_ShouldDisplayErrorOnView() {
        // Given
        let expectedErrorTitle = "Error"
        let expectedErrorMessage = "Some error message"
        let params = AddPersonParameters.createParameters()
        addPersonUseCaseSpy.resultToBeReturned = .failure(CoreError(title: expectedErrorTitle, message: expectedErrorMessage))
        // When
        sut.addButtonPressed(parameters: params)
        // Then
        XCTAssertEqual(expectedErrorTitle, addPersonViewSpy.displayAddPersonErrorTitle, "Error title doesn't match")
        XCTAssertEqual(expectedErrorMessage, addPersonViewSpy.displayAddPersonErrorMessage, "Error message doesn't match")
    }
    
}
