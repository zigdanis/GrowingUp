//
//  DateCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest

@testable import Core
@testable import GrowingUp

final class DateCellPresenterTests: XCTestCase {

	var sut: DateCellPresenterImplementation!

	override func setUp() {
		super.setUp()
		sut = DateCellPresenterImplementation()
	}

	func test_SUT_WhenConfiguredWithDayAndTime_ShouldDisplayCombinedBirthday() {
		// Given
		let birthday = Date()
		sut.valueFor(row: EPC.dayPickerRow, didChangeTo: birthday)
		sut.valueFor(row: EPC.timePickerRow, didChangeTo: birthday)
		let dateCellSpy = DateCellViewSpy()
		// When
		sut.configure(cell: dateCellSpy, forRow: EPC.birthdayRow)
		// Then
		let displayed = try? XCTUnwrap(dateCellSpy.displayedDate)
		XCTAssertEqual(
			displayed?.timeIntervalSince1970 ?? 0,
			birthday.timeIntervalSince1970,
			accuracy: 1,
			"The combined birthday we expected was not displayed")
	}

	func test_SUT_WhenConfiguredWithDate_ShouldReturnThatValue() {
		// Given
		let expectedDate = Date()
		sut.valueFor(row: EPC.dayPickerRow, didChangeTo: expectedDate)
		// When
		let date = sut.valueFor(row: EPC.dayPickerRow)
		// Then
		XCTAssertEqual(date, expectedDate, "The value we expected did not match")
	}

	func test_SUT_WhenConfiguredWithoutData_ShouldDisplayNoDate() {
		// Given
		let dateCellSpy = DateCellViewSpy()
		// When
		sut.configure(cell: dateCellSpy, forRow: EPC.birthdayRow)
		// Then
		XCTAssertNil(dateCellSpy.displayedDate, "No date should be displayed when nothing was set")
	}

	func test_SUT_WhenConfigured_ShouldDisplayBirthdayTitle() {
		// Given
		let dateCellSpy = DateCellViewSpy()
		// When
		sut.configure(cell: dateCellSpy, forRow: EPC.birthdayRow)
		// Then
		XCTAssertEqual(dateCellSpy.displayedTitle, String(localized: "Birthday"), "Expected the birthday title")
	}

}
