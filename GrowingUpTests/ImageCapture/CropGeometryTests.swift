import SwiftUI
import XCTest

@testable import GrowingUp

final class CropGeometryTests: XCTestCase {
	private let phone = CGSize(width: 300, height: 600)

	func testAPhoneCropsTheWholeWindowAndAWideWindowAPortraitColumn() {
		XCTAssertEqual(geometry(container: phone).frameRect, CGRect(origin: .zero, size: phone))
		let wide = geometry(container: CGSize(width: 1000, height: 700)).frameRect
		XCTAssertEqual(wide.width, 490, accuracy: 0.001)
		XCTAssertEqual(wide.midX, 500, accuracy: 0.001)
		XCTAssertEqual(wide.height, 700)
	}

	func testThePhotoAspectFillsTheWindowAtScaleOne() {
		let geometry = geometry(container: phone)
		XCTAssertEqual(geometry.baseScale, 0.5)
		XCTAssertEqual(geometry.displaySize, CGSize(width: 450, height: 600))
		XCTAssertEqual(geometry.minScale, 1, "A phone frame is the whole window, which scale 1 just covers")
		XCTAssertEqual(geometry.clampScale(0.5), 1)
		XCTAssertEqual(geometry.clampScale(9), CropGeometry.maxZoom)
	}

	func testTheOffsetKeepsTheFrameCovered() {
		let geometry = geometry(container: phone)
		XCTAssertEqual(geometry.clampOffset(CGSize(width: 500, height: 40), scale: 1), CGSize(width: 75, height: 0))
		XCTAssertEqual(geometry.clampOffset(CGSize(width: -500, height: -900), scale: 2), CGSize(width: -300, height: -300))
		let banded = geometry.rubberBandOffset(CGSize(width: 200, height: 0), scale: 1)
		XCTAssertGreaterThan(banded.width, 75, "Overscroll gives way")
		XCTAssertLessThan(banded.width, 200, "but resists")
	}

	func testTheCropIsTheVisibleRegionInSourcePixels() {
		let geometry = geometry(container: phone)
		XCTAssertEqual(geometry.cropRect(scale: 1, offset: .zero), CGRect(x: 150, y: 0, width: 600, height: 1200))
		XCTAssertEqual(
			geometry.cropRect(scale: 2, offset: CGSize(width: 75, height: 150)), CGRect(x: 225, y: 150, width: 300, height: 600))
	}

	private func geometry(container: CGSize) -> CropGeometry {
		CropGeometry(pixelSize: CGSize(width: 900, height: 1200), shape: .rectangle, container: container, insets: EdgeInsets())
	}
}
