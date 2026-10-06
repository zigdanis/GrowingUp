import UIKit
import XCTest

@testable import Core

@MainActor
final class ImagesCacheTests: XCTestCase {
	func testWidgetThumbnailBoundsDecodedPixelsAndPreservesOriginal() async throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
		defer { try? FileManager.default.removeItem(at: url) }
		let original = try XCTUnwrap(
			autoreleasepool {
				let format = UIGraphicsImageRendererFormat()
				format.scale = 1
				return UIGraphicsImageRenderer(size: CGSize(width: 3600, height: 2400), format: format).image { context in
					UIColor.systemTeal.setFill()
					context.fill(CGRect(x: 0, y: 0, width: 3600, height: 2400))
				}.jpegData(compressionQuality: 0.9)
			})
		try original.write(to: url)

		let image = try await ImagesCache.loadWidgetImage(at: url)
		let pixels = try XCTUnwrap(image.cgImage)
		XCTAssertEqual(max(pixels.width, pixels.height), 256)
		XCTAssertEqual(Double(pixels.width) / Double(pixels.height), 1.5, accuracy: 0.02)
		XCTAssertEqual(try Data(contentsOf: url), original)
	}

	func testMissingAndCorruptWidgetImagesFailWithoutModifyingFiles() async throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
		defer { try? FileManager.default.removeItem(at: url) }
		let corrupt = Data("not an image".utf8)
		for exists in [false, true] {
			if exists { try corrupt.write(to: url) }
			do {
				_ = try await ImagesCache.loadWidgetImage(at: url)
				XCTFail("Invalid image should use the widget's fallback")
			} catch {
				XCTAssertEqual(error as? CoreError, .missingValue)
			}
		}
		XCTAssertEqual(try Data(contentsOf: url), corrupt)
	}

	func testCancelledWidgetImageLoadPropagatesCancellation() async {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
		let task = Task { try await ImagesCache.loadWidgetImage(at: url) }
		task.cancel()
		do {
			_ = try await task.value
			XCTFail("Cancelled thumbnail load should not continue")
		} catch {
			XCTAssertTrue(error is CancellationError)
		}
	}
}
