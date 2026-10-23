//
//  WorkingImageTests.swift
//  GrowingUpTests
//
//  Covers how an incoming photo becomes the working image (orientation, mirroring, the long-side limit) and that the
//  crop of a working image keeps the framed pixels and stores the same picture as a crop of the original would.
//

import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XCTest

@testable import GrowingUp

@MainActor
final class WorkingImageTests: XCTestCase {
	private let red: [UInt8] = [255, 0, 0]
	private let green: [UInt8] = [0, 255, 0]
	private let blue: [UInt8] = [0, 0, 255]
	private let yellow: [UInt8] = [255, 255, 0]

	func testRotatedPhotoIsDecodedUpright() async throws {
		// Cameras store landscape pixels and mark them to be shown rotated clockwise (EXIF orientation 6),
		// so the stored red left half ends up on top.
		let data = try encoded(photo(width: 400, height: 200, quadrants: [.red, .blue, .red, .blue]), orientation: .right)
		let image = try await WorkingImage.decode(data)
		try assertPixelSize(image, width: 200, height: 400)
		try assertPixel(red, in: image, column: 100, row: 100)
		try assertPixel(blue, in: image, column: 100, row: 300)
	}

	func testMirroredPhotoSwapsLeftAndRight() async throws {
		let data = try encoded(photo(width: 400, height: 200, quadrants: [.red, .blue, .red, .blue]))
		let image = try await WorkingImage.decode(data, mirrored: true)
		try assertPixelSize(image, width: 400, height: 200)
		try assertPixel(blue, in: image, column: 100, row: 100)
		try assertPixel(red, in: image, column: 300, row: 100)
	}

	func testLongSideShrinksToTheLimit() async throws {
		let limit = WorkingImage.maxPixelSide
		let landscape = try await WorkingImage.decode(encoded(photo(width: 5000, height: 100, quadrants: [.red, .blue, .red, .blue])))
		let portrait = try await WorkingImage.decode(encoded(photo(width: 100, height: 5000, quadrants: [.red, .blue, .red, .blue])))
		for (long, short) in [(landscape.size.width, landscape.size.height), (portrait.size.height, portrait.size.width)] {
			XCTAssertLessThanOrEqual(long, CGFloat(limit))
			XCTAssertEqual(long, CGFloat(limit), accuracy: 1)
			XCTAssertEqual(short, 100 * CGFloat(limit) / 5000, accuracy: 1, "The aspect ratio is kept")
		}
	}

	func testSmallPhotoKeepsItsSize() async throws {
		let image = try await WorkingImage.decode(encoded(photo(width: 300, height: 200, quadrants: [.red, .blue, .red, .blue])))
		try assertPixelSize(image, width: 300, height: 200)
	}

	func testDataThatIsNotAPhotoFails() async {
		do {
			_ = try await WorkingImage.decode(Data("not a photo".utf8))
			XCTFail("Expected a decoding error")
		} catch {}
	}

	func testCropTakesTheFramedPixelsOfTheWorkingImage() async throws {
		let image = photo(width: 1200, height: 1600, quadrants: [.red, .green, .blue, .yellow])
		let step = CropStep(image: image, shape: .rectangle, onComplete: { _ in }, onCancel: {})
		// At 2× zoom on a 300 × 600 pt screen, moved right and down, the frame holds source pixels x 300–700, y 200–1000,
		// so the quadrants meet at column 300, row 600 of the crop.
		let cropped = await step.output(
			container: CGSize(width: 300, height: 600), insets: EdgeInsets(), scale: 2, offset: CGSize(width: 75, height: 150))
		try assertPixelSize(cropped, width: 400, height: 800)
		try assertPixel(red, in: cropped, column: 290, row: 590)
		try assertPixel(green, in: cropped, column: 310, row: 590)
		try assertPixel(blue, in: cropped, column: 290, row: 610)
		try assertPixel(yellow, in: cropped, column: 310, row: 610)
	}

	func testWorkingImageStoresTheSamePicturesAsTheOriginal() async throws {
		let original = photo(width: 3600, height: 4800, quadrants: [.red, .green, .blue, .yellow])
		let working = try await WorkingImage.decode(encoded(original, as: .png))
		try assertPixelSize(working, width: 3072, height: 4096)
		for shape in [CropShape.rectangle, .circle] {
			let fromOriginal = await storedCrop(of: original, shape: shape)
			let fromWorking = await storedCrop(of: working, shape: shape)
			XCTAssertEqual(max(fromOriginal.size.width, fromOriginal.size.height), shape.maxPixelSize)
			XCTAssertEqual(fromWorking.size.width, fromOriginal.size.width, accuracy: 1)
			XCTAssertEqual(fromWorking.size.height, fromOriginal.size.height, accuracy: 1)
			for picture in [fromOriginal, fromWorking] {
				let width = Int(picture.size.width)
				let height = Int(picture.size.height)
				try assertPixel(red, in: picture, column: width / 4, row: height / 4)
				try assertPixel(green, in: picture, column: width * 3 / 4, row: height / 4)
				try assertPixel(blue, in: picture, column: width / 4, row: height * 3 / 4)
				try assertPixel(yellow, in: picture, column: width * 3 / 4, row: height * 3 / 4)
			}
		}
	}

	/// The stored picture of an untouched crop on a 300 × 600 pt screen.
	private func storedCrop(of image: UIImage, shape: CropShape) async -> UIImage {
		let step = CropStep(image: image, shape: shape, onComplete: { _ in }, onCancel: {})
		let container = CGSize(width: 300, height: 600)
		let scale = step.minScale(in: container, insets: EdgeInsets())
		return await step.output(container: container, insets: EdgeInsets(), scale: scale, offset: .zero)
	}

	/// A photo split into four quadrants, coloured in reading order.
	private func photo(width: Int, height: Int, quadrants: [UIColor]) -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = true
		format.preferredRange = .standard
		let half = CGSize(width: CGFloat(width) / 2, height: CGFloat(height) / 2)
		return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
			for (index, color) in quadrants.enumerated() {
				color.setFill()
				let origin = CGPoint(x: CGFloat(index % 2) * half.width, y: CGFloat(index / 2) * half.height)
				context.fill(CGRect(origin: origin, size: half))
			}
		}
	}

	/// The photo as a file from the library or the camera would hold it, with an EXIF orientation.
	private func encoded(_ image: UIImage, as type: UTType = .jpeg, orientation: CGImagePropertyOrientation = .up) throws -> Data {
		let pixels = try XCTUnwrap(image.cgImage)
		let data = NSMutableData()
		let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, 1, nil))
		CGImageDestinationAddImage(destination, pixels, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
		XCTAssertTrue(CGImageDestinationFinalize(destination))
		return data as Data
	}

	private func assertPixelSize(_ image: UIImage, width: Int, height: Int, file: StaticString = #filePath, line: UInt = #line) throws {
		let pixels = try XCTUnwrap(image.cgImage, file: file, line: line)
		XCTAssertEqual(pixels.width, width, file: file, line: line)
		XCTAssertEqual(pixels.height, height, file: file, line: line)
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
