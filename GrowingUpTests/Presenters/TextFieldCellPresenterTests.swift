//
//  TextFieldCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

final class TextFieldCellPresenterTests: XCTestCase {

	var sut: TextFieldCellPresenterImplementation!

	override func setUp() {
		super.setUp()
		sut = TextFieldCellPresenterImplementation()
	}

	func test_SUT_ConfigureTextFieldCell_HasNameTitle() {
		// Given
		let expectedName = "John"
		sut.valueFor(row: 0, didChangeTo: expectedName)
		let tfCellSpy = TextFieldCellViewSpy()
		// When
		sut.configure(cell: tfCellSpy, forRow: 0)
		// Then
		XCTAssertEqual(expectedName, tfCellSpy.displayedValue, "The value we expected was not displayed")
	}

	func test_SUT_WhenConfiguredCellForRow_DifferResultsForRows() {
		// Given
		let expectedName = "John"
		sut.valueFor(row: 0, didChangeTo: expectedName)
		let tfCellSpy = TextFieldCellViewSpy()
		// When
		sut.configure(cell: tfCellSpy, forRow: 1)
		// Then
		XCTAssertNotEqual(expectedName, tfCellSpy.displayedValue, "The value displayed should not be same as provided for 0-th row")
	}

	func test_SUT_WhenConfiguredWithoutData_ChangesValueAfterUserInput() {
		// Given
		let tfCellSpy = TextFieldCellViewSpy()
		let expectedName = "John"
		// When
		sut.configure(cell: tfCellSpy, forRow: 0)
		tfCellSpy.presenter?.valueFor(row: 0, didChangeTo: expectedName)
		// Then
		XCTAssertEqual(expectedName, sut.valueFor(row: 0), "The model value in presenter didn't updated after user input")
	}

	func test_SUT_WhenConfiguringCell_PassingObserverToIt() {
		// Given
		let tfCellSpy = TextFieldCellViewSpy()
		let expectedObserver = TextFieldObserverSpy()
		let expectedText = "Hello"
		sut.textFieldObserver = expectedObserver
		// When
		sut.configure(cell: tfCellSpy, forRow: 0)
		tfCellSpy.observer?.textDidChange(forView: tfCellSpy, text: expectedText)
		// Then
		XCTAssertEqual(expectedObserver.didChangeText, expectedText, "Expected to pass Observer to the TextFieldCellView and change text accordingly")
	}

}
