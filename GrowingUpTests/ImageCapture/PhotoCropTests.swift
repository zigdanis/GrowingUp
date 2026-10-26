import Core
import UIKit
import XCTest

@testable import GrowingUp

/// A picture's region of the original: how it is stored, and the pixels it takes from the original.
final class PhotoCropTests: XCTestCase {
	func testARegionIsAFractionOfThePhotoWhateverItsSize() {
		let crop = PhotoCrop(CGRect(x: 225, y: 150, width: 300, height: 600), in: CGSize(width: 900, height: 1200))
		XCTAssertEqual(crop, PhotoCrop(minX: 0.25, minY: 0.125, width: 1.0 / 3, height: 0.5))
		let doubled = crop.rect(in: CGSize(width: 1800, height: 2400))
		XCTAssertEqual(doubled.minX, 450, accuracy: 1e-9)
		XCTAssertEqual(doubled.minY, 300, accuracy: 1e-9)
		XCTAssertEqual(doubled.width, 600, accuracy: 1e-9)
		XCTAssertEqual(doubled.height, 1200, accuracy: 1e-9)
	}

	func testTheStoredValueReadsBackExactly() {
		let crop = PhotoCrop(minX: 1.0 / 3, minY: 0.1, width: 0.2, height: 2.0 / 7)
		XCTAssertEqual(PhotoCrop(storedValue: crop.storedValue), crop)
		XCTAssertEqual(PhotoCrop.whole.storedValue, "0.0,0.0,1.0,1.0")
	}

	func testAMalformedOrEmptyStoredValueIsUnknown() {
		for value in [nil, "", "0,0,1", "0,0,1,1,1", "a,b,c,d", "0,0,0,1", "0,0,1,-1", "nan,0,1,1", "0,0,inf,1"] {
			XCTAssertNil(PhotoCrop(storedValue: value), value ?? "nil")
		}
	}

	func testCroppingTakesTheRegionsPixelsAtTheOriginalsResolution() throws {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let original = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600), format: format).image { context in
			UIColor.red.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
			UIColor.blue.setFill()
			context.fill(CGRect(x: 600, y: 800, width: 600, height: 800))
		}
		let cropped = original.cropped(to: PhotoCrop(minX: 0.25, minY: 0.25, width: 0.5, height: 0.5))
		let pixels = try XCTUnwrap(cropped.cgImage)
		XCTAssertEqual(pixels.width, 600)
		XCTAssertEqual(pixels.height, 800)
		// Float noise from a region read back off disk still lands on the same pixel edges.
		let noisy = original.cropped(to: PhotoCrop(minX: 0.25 + 1e-12, minY: 0.25 - 1e-12, width: 0.5 + 1e-12, height: 0.5))
		XCTAssertEqual(noisy.cgImage?.width, 600)
		XCTAssertEqual(noisy.cgImage?.height, 800)
	}
}
