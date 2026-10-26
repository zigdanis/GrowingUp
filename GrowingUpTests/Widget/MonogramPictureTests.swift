import UIKit
import XCTest

@testable import GrowingUp

final class MonogramPictureTests: XCTestCase {
	/// The hue must not use `hashValue`, which Swift seeds differently on every launch, or a person's colour would change.
	func testHueIsFixedForAnId() throws {
		let id = try XCTUnwrap(UUID(uuidString: "6FC31834-C9E3-4EFB-A1FA-4A701B51B443"))
		XCTAssertEqual(MonogramPicture.hue(for: id), MonogramPicture.hue(for: id))
		XCTAssertEqual(MonogramPicture.hue(for: id), 24.0 / 360, accuracy: 0.0001, "A changed hue recolours every existing monogram")
	}

	func testDifferentPeopleUsuallyGetDifferentHues() {
		let hues = Set((0..<20).map { _ in MonogramPicture.hue(for: UUID()) })
		XCTAssertGreaterThan(hues.count, 10)
	}

	/// Drawn like a widget photo: a small square in standard range, so it archives within the extension's memory limit.
	func testPictureIsASmallStandardRangeSquare() throws {
		let picture = MonogramPicture.draw(id: UUID(), name: "Clara")
		let cgImage = try XCTUnwrap(picture.cgImage)
		XCTAssertEqual(cgImage.width, 256)
		XCTAssertEqual(cgImage.height, 256)
		XCTAssertFalse(cgImage.bitmapInfo.contains(.floatComponents))
		XCTAssertFalse(CGColorSpaceUsesExtendedRange(try XCTUnwrap(cgImage.colorSpace)))
	}

	/// The mosaic tile draws the same picture in its portrait shape, in standard range like the widget's square.
	func testPortraitPictureIsDrawnAtItsSize() throws {
		let portrait = try XCTUnwrap(MonogramPicture.draw(id: UUID(), name: "Clara", size: CGSize(width: 540, height: 960)).cgImage)
		XCTAssertEqual(portrait.width, 540)
		XCTAssertEqual(portrait.height, 960)
		XCTAssertFalse(CGColorSpaceUsesExtendedRange(try XCTUnwrap(portrait.colorSpace)))
	}

	/// The monogram stands in for the photo in tiles only; the Lock Screen keeps showing no photo. The final picture, scrims
	/// included, must stay in standard range like a photo, or archiving it can exceed the extension's memory limit.
	func testPersonWithoutPhotoGetsAStandardRangeMonogramTilePicture() throws {
		let person = WidgetPerson(id: UUID(), index: 0, name: "Clara", birthday: Date(), image: nil)
		XCTAssertNil(person.photo)
		let cgImage = try XCTUnwrap(person.tilePicture.cgImage)
		XCTAssertEqual(cgImage.width, 256)
		XCTAssertEqual(cgImage.height, 256)
		XCTAssertFalse(cgImage.bitmapInfo.contains(.floatComponents))
		XCTAssertFalse(CGColorSpaceUsesExtendedRange(try XCTUnwrap(cgImage.colorSpace)))
	}
}
