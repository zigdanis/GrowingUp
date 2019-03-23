//
//  ImagesCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 23/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp

class ImagesCellPresenterTests: XCTestCase {

	let imagesCellSpy = ImagesCellViewSpy()
	var sut: ImagesCellPresenterImplementation!

	override func setUp() {
		super.setUp()
		sut = ImagesCellPresenterImplementation()
	}

	func test_SUT_ConfiguredWithImages_DisplayImagesOnCell() {
		// Given
		let expectedPics: PersonPics = (UIImage(), UIImage())
		sut.valueFor(row: APC.imagePickerRow, didChangeTo: expectedPics)
		// When
		sut.configure(cell: imagesCellSpy, forRow: APC.imagePickerRow)
		// Then
		XCTAssertEqual(imagesCellSpy.displayedAppPic, expectedPics.appPic, "Value displayed on cell doesn't match to expected")
		XCTAssertEqual(imagesCellSpy.displayedWidgetPic, expectedPics.widgetPic, "Value displayed on cell doesn't match to expected")
	}

	func test_SUT_WithoutConfiguring_DoNotDisplayImagesOnCell() {
		// When
		sut.configure(cell: imagesCellSpy, forRow: APC.imagePickerRow)
		// Then
		XCTAssertNil(imagesCellSpy.displayedAppPic, "Expected to have nil images displayed")
		XCTAssertNil(imagesCellSpy.displayedWidgetPic, "Expected to have nil images displayed")
	}

	func test_SUT_AfterChangingConfiguredImages_DisplayChangesOnCell() {
		// Given
		let initialPics: PersonPics = (UIImage(), UIImage())
		let expectedPics: PersonPics = (UIImage(), UIImage())
		let emptyPics: PersonPics = (nil, nil)
		sut.valueFor(row: APC.imagePickerRow, didChangeTo: initialPics)
		// When
		sut.configure(cell: imagesCellSpy, forRow: APC.imagePickerRow)
		sut.valueFor(row: APC.imagePickerRow, didChangeTo: expectedPics)
		sut.configure(cell: imagesCellSpy, forRow: APC.imagePickerRow)
		// Then
		XCTAssertEqual(imagesCellSpy.displayedAppPic, expectedPics.appPic, "Value displayed on cell doesn't match to expected")
		XCTAssertEqual(imagesCellSpy.displayedWidgetPic, expectedPics.widgetPic, "Value displayed on cell doesn't match to expected")
		// When
		sut.valueFor(row: APC.imagePickerRow, didChangeTo: emptyPics)
		sut.configure(cell: imagesCellSpy, forRow: APC.imagePickerRow)
		XCTAssertNil(imagesCellSpy.displayedAppPic, "Expected to have nil images displayed")
		XCTAssertNil(imagesCellSpy.displayedWidgetPic, "Expected to have nil images displayed")
	}
}
