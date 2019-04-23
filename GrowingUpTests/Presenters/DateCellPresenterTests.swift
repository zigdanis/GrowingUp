//
//  LabelCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

final class DateCellPresenterTests: XCTestCase {

	var sut: DateCellPresenterImplementation!

	override func setUp() {
		super.setUp()
		sut = DateCellPresenterImplementation()
	}

	func test_SUT_WhenConfiguredWithDate_ShouldDisplayValue() {
		// Given
		let date = Date()
		sut.valueFor(row: EPC.dayPickerRow, didChangeTo: date)
		let dateCellSpy = DateCellViewSpy()
		// When
		sut.configure(cell: dateCellSpy, forRow: EPC.dayPickerRow)
		// Then
		XCTAssertEqual(date.dateString(), dateCellSpy.displayedValue, "The value we expected was not displayed")
	}

	func test_SUT_WhenConfiguredWithDate_ShouldReturnThatValue() {
		// Given
		let expectedDate = Date()
		sut.valueFor(row: EPC.dayPickerRow, didChangeTo: expectedDate)
		// When
		let date = sut.valueFor(row: EPC.dayPickerRow)
		// Then
		XCTAssertEqual(date, expectedDate, "The value we expected did npt match")
	}

	func test_SUT_WhenConfiguredWithoutData_ShouldShowPlaceholders() {
		// Given
		let dateCellSpy = DateCellViewSpy()
		// When
		sut.configure(cell: dateCellSpy, forRow: EPC.dayPickerRow)
		// Then
		XCTAssertEqual("xx.xx.xxxx", dateCellSpy.displayedValue, "The Value we expected was not displayed")
	}

}
