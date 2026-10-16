import Core
import UIKit
import XCTest

final class WidgetPictureDeriverTests: XCTestCase {
	private let green: [UInt8] = [0, 255, 0]
	private let blue: [UInt8] = [0, 0, 255]

	func testPortraitPhotoKeepsItsCenteredSquare() throws {
		let photo = image(width: 900, height: 1200) { context in
			UIColor.blue.setFill()
			context.fill(CGRect(x: 0, y: 150, width: 900, height: 900))
		}
		let derived = WidgetPictureDeriver.derive(from: photo)
		try assertSquare(derived, side: 480)
		for point in [10, 240, 470] {
			try assertPixel(blue, in: derived, column: point, row: point)
		}
	}

	func testLandscapePhotoKeepsItsCenteredSquare() throws {
		let photo = image(width: 1200, height: 900) { context in
			UIColor.blue.setFill()
			context.fill(CGRect(x: 150, y: 0, width: 900, height: 900))
		}
		let derived = WidgetPictureDeriver.derive(from: photo)
		try assertSquare(derived, side: 480)
		for point in [10, 240, 470] {
			try assertPixel(blue, in: derived, column: point, row: point)
		}
	}

	func testSmallSquarePhotoIsNotUpscaled() throws {
		let photo = image(width: 300, height: 300) { context in
			UIColor.green.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
		}
		let derived = WidgetPictureDeriver.derive(from: photo)
		try assertSquare(derived, side: 300)
		try assertPixel(green, in: derived, column: 150, row: 150)
	}

	func testRotatedCameraPhotoIsDerivedUpright() throws {
		// Camera photos store landscape pixels and display them rotated clockwise (`.right`).
		// The stored bands below appear as a green left half and a blue right half once upright.
		let stored = image(width: 1200, height: 900) { context in
			UIColor.green.setFill()
			context.fill(CGRect(x: 150, y: 450, width: 900, height: 450))
			UIColor.blue.setFill()
			context.fill(CGRect(x: 150, y: 0, width: 900, height: 450))
		}
		let storedPixels = try XCTUnwrap(stored.cgImage)
		let photo = UIImage(cgImage: storedPixels, scale: 1, orientation: .right)
		XCTAssertEqual(photo.size, CGSize(width: 900, height: 1200))
		let derived = WidgetPictureDeriver.derive(from: photo)
		try assertSquare(derived, side: 480)
		try assertPixel(green, in: derived, column: 100, row: 240)
		try assertPixel(blue, in: derived, column: 380, row: 240)
	}

	private func image(width: Int, height: Int, draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let size = CGSize(width: width, height: height)
		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			UIColor.red.setFill()
			context.fill(CGRect(origin: .zero, size: size))
			draw(context)
		}
	}

	private func assertSquare(_ image: UIImage, side: Int, file: StaticString = #filePath, line: UInt = #line) throws {
		let pixels = try XCTUnwrap(image.cgImage, file: file, line: line)
		XCTAssertEqual(pixels.width, side, file: file, line: line)
		XCTAssertEqual(pixels.height, side, file: file, line: line)
		XCTAssertEqual(image.imageOrientation, .up, file: file, line: line)
	}

	private func assertPixel(
		_ expected: [UInt8], in image: UIImage, column: Int, row: Int, file: StaticString = #filePath, line: UInt = #line
	) throws {
		let actual = try pixel(in: image, column: column, row: row)
		let matches = zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= 40 }
		XCTAssertTrue(matches, "Pixel at \(column), \(row) is \(actual), expected \(expected)", file: file, line: line)
	}

	/// Reads one sRGB pixel, addressed from the top-left corner.
	private func pixel(in image: UIImage, column: Int, row: Int) throws -> [UInt8] {
		let pixels = try XCTUnwrap(image.cgImage)
		let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
		let context = try XCTUnwrap(
			CGContext(
				data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: sRGB,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
		// Core Graphics counts rows from the bottom; shift the image so the requested pixel covers the 1×1 canvas.
		context.draw(pixels, in: CGRect(x: -column, y: row + 1 - pixels.height, width: pixels.width, height: pixels.height))
		let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
		return [bytes[0], bytes[1], bytes[2]]
	}
}
