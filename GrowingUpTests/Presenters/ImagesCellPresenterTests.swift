//
//  ImagesCellPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 23/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation
import XCTest

@testable import Core
@testable import GrowingUp

class ImagesCellPresenterTests: XCTestCase {

	let imagesCellSpy = ImagesCellViewSpy()
	let addPersonViewSpy = EditPersonViewSpy()
	var sut: ImagesCellPresenterImplementation!

	override func setUp() {
		super.setUp()
		sut = ImagesCellPresenterImplementation()
	}

	func test_SUT_ConfiguredWithImages_DisplayImagesOnCell() {
		// Given
		let appPic = PersonImage(id: UUID(), uiImage: UIImage())
		let widgetPic = PersonImage(id: UUID(), uiImage: UIImage())
		let expectedPics = PersonImages(appPic: appPic, widgetPic: widgetPic)
		sut.valueFor(row: EPC.imagePickerRow, didChangeTo: expectedPics)
		// When
		sut.configure(cell: imagesCellSpy, forRow: EPC.imagePickerRow, with: addPersonViewSpy)
		// Then
		XCTAssertEqual(imagesCellSpy.displayedAppPic, appPic, "Value displayed on cell doesn't match to expected")
		XCTAssertEqual(imagesCellSpy.displayedWidgetPic, widgetPic, "Value displayed on cell doesn't match to expected")
	}

	func test_SUT_WithoutConfiguring_DoNotDisplayImagesOnCell() {
		// When
		sut.configure(cell: imagesCellSpy, forRow: EPC.imagePickerRow, with: addPersonViewSpy)
		// Then
		XCTAssertNil(imagesCellSpy.displayedAppPic, "Expected to have nil images displayed")
		XCTAssertNil(imagesCellSpy.displayedWidgetPic, "Expected to have nil images displayed")
	}

	func test_SUT_AfterChangingConfiguredImages_DisplayChangesOnCell() {
		// Given
		let initialAppPic = PersonImage(id: UUID(), uiImage: UIImage())
		let initialWidgetPic = PersonImage(id: UUID(), uiImage: UIImage())
		let initialPics = PersonImages(appPic: initialAppPic, widgetPic: initialWidgetPic)
		let expectedAppPic = PersonImage(id: UUID(), uiImage: UIImage())
		let expectedWidgetPic = PersonImage(id: UUID(), uiImage: UIImage())
		let expectedPics = PersonImages(appPic: expectedAppPic, widgetPic: expectedWidgetPic)
		let emptyPics = PersonImages(appPic: nil, widgetPic: nil)
		sut.valueFor(row: EPC.imagePickerRow, didChangeTo: initialPics)
		// When
		sut.configure(cell: imagesCellSpy, forRow: EPC.imagePickerRow, with: addPersonViewSpy)
		sut.valueFor(row: EPC.imagePickerRow, didChangeTo: expectedPics)
		sut.configure(cell: imagesCellSpy, forRow: EPC.imagePickerRow, with: addPersonViewSpy)
		// Then
		XCTAssertEqual(
			imagesCellSpy.displayedAppPic, expectedPics.appPic, "Value displayed on cell doesn't match to expected")
		XCTAssertEqual(
			imagesCellSpy.displayedWidgetPic, expectedPics.widgetPic, "Value displayed on cell doesn't match to expected")
		// When
		sut.valueFor(row: EPC.imagePickerRow, didChangeTo: emptyPics)
		sut.configure(cell: imagesCellSpy, forRow: EPC.imagePickerRow, with: addPersonViewSpy)
		XCTAssertNil(imagesCellSpy.displayedAppPic, "Expected to have nil images displayed")
		XCTAssertNil(imagesCellSpy.displayedWidgetPic, "Expected to have nil images displayed")
	}

}
