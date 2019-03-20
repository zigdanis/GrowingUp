//
//  LabelCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp

final class DateCellPresenterTests: XCTestCase {
	
	var sut = DateCellPresenterImplementation()
	
	func test_SUT_WhenConfiguredWithDate_ShouldDisplayValue() {
		// Given
		let date = Date()
		sut.valuesForRow[1] = date
		let labelCellSpy = DateCellViewSpy()
		// When
		sut.configure(cell: labelCellSpy, forRow: 1)
		// Then
		XCTAssertEqual(date.dateString(), labelCellSpy.displayedValue, "The value we expected was not displayed")
	}
	

}


