//
//  ToggleCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/09/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest

@testable import Core
@testable import GrowingUp

final class ToggleCellPresenterTests: XCTestCase {

	var sut: ToggleCellPresenterImplementation!

	override func setUp() {
		super.setUp()
		sut = ToggleCellPresenterImplementation()
	}

	func test_SUT_ConfiguredWithValue_GetsSetWithThatValue() {
		// Given
		let expectedValue = true
		sut.valueFor(row: 0, didChangeTo: expectedValue)
		let cell = ToggleCellViewSpy()
		// When
		sut.configure(cell: cell, forRow: 0)
		// Then
		XCTAssertEqual(expectedValue, cell.displayedValue, "The value we expected were not displayed")
	}

	func test_SUT_ConfiguredWithValueForRow0_NotEqualToValueOnRow1() {
		// Given
		let expectedValue = true
		sut.valueFor(row: 0, didChangeTo: expectedValue)
		let cell = ToggleCellViewSpy()
		// When
		sut.configure(cell: cell, forRow: 1)
		// Then
		XCTAssertNotEqual(expectedValue, cell.displayedValue, "We expected to have different values for different rows")
	}

}
