import Core
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

	func testPhonesAndIPhoneDuoKeepTheirFramesExactly() {
		// iPhone 17 Pro Max, iPhone Duo's outer display, and its inner display upright and on its side.
		XCTAssertEqual(rectangle(CGSize(width: 440, height: 956), .phone), CGRect(x: 0, y: 0, width: 440, height: 956))
		XCTAssertEqual(rectangle(CGSize(width: 466, height: 678), .phone), CGRect(x: 0, y: 0, width: 466, height: 678))
		XCTAssertEqual(rectangle(CGSize(width: 669, height: 951), .phone), column(in: CGSize(width: 669, height: 951), width: 951 * CropGeometry.maxMainAspect))
		XCTAssertEqual(rectangle(CGSize(width: 951, height: 669), .phone), column(in: CGSize(width: 951, height: 669), width: 669 * CropGeometry.maxMainAspect))
		// Every phone window frames as before the iPad rule: the whole window, or a column `maxMainAspect` of its height.
		for width in stride(from: CGFloat(280), through: 1400, by: 7) {
			for height in stride(from: CGFloat(300), through: 1400, by: 9) {
				let size = CGSize(width: width, height: height)
				let before =
					width / height > CropGeometry.maxMainAspect
					? CGRect(x: (width - height * 0.7) / 2, y: 0, width: height * 0.7, height: height)
					: CGRect(origin: .zero, size: size)
				XCTAssertEqual(rectangle(size, .phone), before, "\(size)")
			}
		}
	}

	func testIPadKeepsDimmedBarsBesideTheColumn() {
		XCTAssertEqual(rectangle(CGSize(width: 1032, height: 1376), .pad), column(in: CGSize(width: 1032, height: 1376), width: 936))
		XCTAssertEqual(rectangle(CGSize(width: 820, height: 1180), .pad), column(in: CGSize(width: 820, height: 1180), width: 724))
		XCTAssertEqual(rectangle(CGSize(width: 744, height: 1133), .pad), column(in: CGSize(width: 744, height: 1133), width: 648))
		let landscape = CGSize(width: 1376, height: 1032)
		XCTAssertEqual(rectangle(landscape, .pad), rectangle(landscape, .phone), "A landscape column already leaves wide bars")
		XCTAssertEqual(rectangle(CGSize(width: 375, height: 1032), .pad), CGRect(x: 0, y: 0, width: 375, height: 1032), "A phone-sized window")
		let circle = CGSize(width: 1032, height: 1376)
		XCTAssertEqual(
			CropGeometry.frameRect(for: .circle, in: circle, insets: EdgeInsets(), idiom: .pad),
			CropGeometry.frameRect(for: .circle, in: circle, insets: EdgeInsets(), idiom: .phone), "The circle keeps its frame")
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

	func testAFramingIsSavedAsARegionThatOpensWhereItWasFramed() throws {
		let geometry = geometry(container: phone)
		let crop = try XCTUnwrap(geometry.crop(scale: 2, offset: CGSize(width: 75, height: 150)))
		XCTAssertEqual(crop, PhotoCrop(minX: 0.25, minY: 0.125, width: 1.0 / 3, height: 0.5))
		assertFraming(geometry.framing(showing: crop), scale: 2, offset: CGSize(width: 75, height: 150))
		// A larger window of the same shape shows the same region.
		let larger = self.geometry(container: CGSize(width: 400, height: 800))
		let there = larger.framing(showing: crop)
		let shown = try XCTUnwrap(larger.crop(scale: there.scale, offset: there.offset))
		XCTAssertEqual(shown.minX, crop.minX, accuracy: 1e-9)
		XCTAssertEqual(shown.minY, crop.minY, accuracy: 1e-9)
		XCTAssertEqual(shown.width, crop.width, accuracy: 1e-9)
		XCTAssertEqual(shown.height, crop.height, accuracy: 1e-9)
	}

	func testACircleOpensOnTheRegionItWasFramedOn() throws {
		let insets = EdgeInsets(top: 50, leading: 0, bottom: 30, trailing: 0)
		let circle = CropGeometry(
			pixelSize: CGSize(width: 900, height: 1200), shape: .circle, container: phone, insets: insets, idiom: .phone)
		let offset = CGSize(width: -40, height: 60)
		XCTAssertEqual(circle.clampOffset(offset, scale: 1.7), offset, "An off-centre framing the circle allows")
		let crop = try XCTUnwrap(circle.crop(scale: 1.7, offset: offset))
		XCTAssertEqual(crop.width * 900, crop.height * 1200, accuracy: 1e-6, "A circle's region is square in pixels")
		assertFraming(circle.framing(showing: crop), scale: 1.7, offset: offset)
	}

	func testARegionBeyondTheLimitsOpensAsNearAsTheyAllow() {
		let geometry = geometry(container: phone)
		let sliver = geometry.framing(showing: PhotoCrop(minX: 0.95, minY: 0.9, width: 0.01, height: 0.02))
		XCTAssertEqual(sliver.scale, CropGeometry.maxZoom, "No deeper than the zoom limit")
		XCTAssertEqual(sliver.offset, geometry.clampOffset(sliver.offset, scale: sliver.scale), "and the frame stays covered")
		let whole = geometry.framing(showing: .whole)
		XCTAssertEqual(whole, .identity, "A whole picture opens as the viewer shows it")
	}

	private func assertFraming(
		_ framing: PhotoFraming, scale: CGFloat, offset: CGSize, file: StaticString = #filePath, line: UInt = #line
	) {
		XCTAssertEqual(framing.scale, scale, accuracy: 1e-9, file: file, line: line)
		XCTAssertEqual(framing.offset.width, offset.width, accuracy: 1e-9, file: file, line: line)
		XCTAssertEqual(framing.offset.height, offset.height, accuracy: 1e-9, file: file, line: line)
	}

	private func geometry(container: CGSize) -> CropGeometry {
		CropGeometry(pixelSize: CGSize(width: 900, height: 1200), shape: .rectangle, container: container, insets: EdgeInsets(), idiom: .phone)
	}

	private func rectangle(_ container: CGSize, _ idiom: UIUserInterfaceIdiom) -> CGRect {
		CropGeometry.frameRect(for: .rectangle, in: container, insets: EdgeInsets(), idiom: idiom)
	}

	private func column(in container: CGSize, width: CGFloat) -> CGRect {
		CGRect(x: (container.width - width) / 2, y: 0, width: width, height: container.height)
	}
}
