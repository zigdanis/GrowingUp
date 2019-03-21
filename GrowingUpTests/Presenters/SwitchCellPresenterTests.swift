//
//  SwitchCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp

class SwitchCellPresenterTests: XCTestCase {
	
	var sut: SwitchCellPresenterImplementation!

    override func setUp() {
		sut = SwitchCellPresenterImplementation()
    }
	
	func test_SUT_WhenConfiguredWithTrue_DisplayTrueValue() {
		// Given
		sut.valueFor(row: 3, didChangeTo: true)
		let switchCellSpy = SwitchCellViewSpy()
		// When
		sut.configure(cell: switchCellSpy, forRow: 3)
		// Then
		XCTAssertEqual(switchCellSpy.displayedStatus, true, "The value we expected was not displayed")
	}
	
	func test_SUT_WhenConfiguredWithFalse_DisplayFalseValue() {
		// Given
		sut.valueFor(row: 3, didChangeTo: false)
		let switchCellSpy = SwitchCellViewSpy()
		// When
		sut.configure(cell: switchCellSpy, forRow: 3)
		// Then
		XCTAssertEqual(switchCellSpy.displayedStatus, false, "The value we expected was not displayed")
	}
	
	func test_SUT_WhenConfiguredWithData_ProduceExpectedParameters() {
		// Given
		let components = AddPersonDateComponents(years: true, months: false, days: true, hours: false, minutes: true, seconds: false)
		// When
		
		let valuesForRow = [ 3: true,
							 4: false,
							 5: true,
							 6: false,
							 7: true,
							 8: false ]
		for (key, value) in valuesForRow {
			sut.valueFor(row: key, didChangeTo: value)
		}
		// Then
		XCTAssertEqual(sut.updatedComponents(), components, "The value we expected was not produced")
	}
}
