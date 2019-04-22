//
//  SwitchCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

class SwitchCellPresenterTests: XCTestCase {

	var sut: SwitchCellPresenterImplementation!

    override func setUp() {
		sut = SwitchCellPresenterImplementation()
    }

	func test_SUT_WhenConfiguredWithTrue_DisplayTrueValue() {
		// Given
		sut.valueFor(row: EPC.dateComponentsRows.lowerBound, didChangeTo: true)
		let switchCellSpy = SwitchCellViewSpy()
		// When
		sut.configure(cell: switchCellSpy, forRow: EPC.dateComponentsRows.lowerBound)
		// Then
		XCTAssertEqual(switchCellSpy.displayedStatus, true, "The value we expected was not displayed")
	}

	func test_SUT_WhenConfiguredWithFalse_DisplayFalseValue() {
		// Given
		sut.valueFor(row: EPC.dateComponentsRows.lowerBound, didChangeTo: false)
		let switchCellSpy = SwitchCellViewSpy()
		// When
		sut.configure(cell: switchCellSpy, forRow: EPC.dateComponentsRows.lowerBound)
		// Then
		XCTAssertEqual(switchCellSpy.displayedStatus, false, "The value we expected was not displayed")
	}

	func test_SUT_WhenConfiguredWithData_ProduceExpectedParameters() {
		// Given
		var components = AddPersonDateComponents()
		components.months = false
		components.hours = false
		components.seconds = false

		let valuesForRow = [ 4: true,
							 5: false,
							 6: true,
							 7: false,
							 8: true,
							 9: false ]
		for (key, value) in valuesForRow {
			sut.valueFor(row: key, didChangeTo: value)
		}
		// Then
		XCTAssertEqual(sut.updatedComponents(), components, "The value we expected was not produced")
	}
}
