//
//  TextFieldCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp

final class TextFieldCellPresenterTests: XCTestCase {
	
	var sut = TextFieldCellPresenterImplementation()
	
	func test_SUT_ConfigureTextFieldCell_HasNameTitle() {
		// Given
		sut.valuesForRow[0] = "John"
		let tfCellSpy = TextFieldCellViewSpy()
		// When
		sut.configure(cell: tfCellSpy, forRow: 0)
		// Then
		XCTAssertEqual("John", tfCellSpy.displayedValue, "The value we expected was not displayed")
	}
	
	func test_SUT_WhenConfiguredCellForRow_DifferResultsForRows() {
		// Given
		sut.valuesForRow[0] = "John"
		let tfCellSpy = TextFieldCellViewSpy()
		// When
		sut.configure(cell: tfCellSpy, forRow: 1)
		// Then
		XCTAssertNotEqual("John", tfCellSpy.displayedValue, "The value displayed should not be same as provided for 0-th row")
	}
	
}

