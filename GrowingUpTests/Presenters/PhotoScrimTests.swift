import UIKit
import XCTest

@testable import GrowingUp

final class PhotoScrimTests: XCTestCase {
	func testScrimDarkensTheTopAndBottomEdgesOfTheSquareCrop() throws {
		let white = solidWhiteImage(width: 20, height: 40)
		let scrimmed = PhotoScrim.apply(to: white)
		XCTAssertEqual(scrimmed.size, CGSize(width: 20, height: 20), "The longer side is cropped")
		XCTAssertEqual(scrimmed.scale, white.scale)
		let brightness = try brightnessPerRow(of: scrimmed)
		XCTAssertEqual(brightness.count, 20)
		let middle = brightness[10]
		XCTAssertGreaterThan(middle, 0.9, "The centre is not darkened")
		XCTAssertLessThan(brightness[0], middle - 0.15, "The top edge is darkened")
		XCTAssertLessThan(brightness[19], middle - 0.3, "The bottom edge is darkened more")
		XCTAssertLessThan(brightness[19], brightness[0])
	}

	func testPicturesAPixelOffSquareBecomeExactlySquare() {
		XCTAssertEqual(PhotoScrim.apply(to: solidWhiteImage(width: 256, height: 255)).size, CGSize(width: 255, height: 255))
		XCTAssertEqual(PhotoScrim.apply(to: solidWhiteImage(width: 255, height: 256)).size, CGSize(width: 255, height: 255))
	}

	func testScrimmedPhotosAre8BitSRGBEvenFromExtendedRangeSources() throws {
		let cgImage = try XCTUnwrap(PhotoScrim.apply(to: try extendedRangeWhiteImage(side: 64)).cgImage)
		XCTAssertEqual(cgImage.bitsPerComponent, 8)
		XCTAssertFalse(cgImage.bitmapInfo.contains(.floatComponents))
		XCTAssertEqual(cgImage.colorSpace?.name, CGColorSpace.sRGB)
	}

	private func solidWhiteImage(width: CGFloat, height: CGFloat) -> UIImage {
		let size = CGSize(width: width, height: height)
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = true
		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			UIColor.white.setFill()
			context.fill(CGRect(origin: .zero, size: size))
		}
	}

	/// A white square in 16-bit float extended sRGB, the pixel format that extended-range displays give the default renderer.
	private func extendedRangeWhiteImage(side: Int) throws -> UIImage {
		let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedSRGB))
		let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
		let context = try XCTUnwrap(
			CGContext(data: nil, width: side, height: side, bitsPerComponent: 16, bytesPerRow: 0, space: space, bitmapInfo: bitmapInfo))
		context.setFillColor(CGColor(gray: 1, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: side, height: side))
		let image = try XCTUnwrap(context.makeImage())
		XCTAssertEqual(image.bitsPerComponent, 16)
		XCTAssertTrue(image.bitmapInfo.contains(.floatComponents))
		return UIImage(cgImage: image)
	}

	/// The red channel, from 0 to 1, of the first pixel of each row from the top; the scrim is black so the channels agree.
	/// The image is redrawn into an RGBA bitmap first, so the result does not depend on the pixel format of the renderer.
	private func brightnessPerRow(of image: UIImage) throws -> [CGFloat] {
		let cgImage = try XCTUnwrap(image.cgImage)
		let width = cgImage.width
		let height = cgImage.height
		var pixels = [UInt8](repeating: 0, count: width * height * 4)
		let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
			guard
				let context = CGContext(
					data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
					space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
			else { return false }
			context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
			return true
		}
		XCTAssertTrue(drawn)
		return (0..<height).map { CGFloat(pixels[$0 * width * 4]) / 255 }
	}
}
