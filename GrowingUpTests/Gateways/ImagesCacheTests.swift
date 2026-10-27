import Disk
import UIKit
import XCTest

@testable import Core

@MainActor
final class ImagesCacheTests: XCTestCase {
	func testDiskLoadPopulatesMemoryCacheAndSurvivesDiskRemoval() async throws {
		let photo = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
			UIColor.orange.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
		}
		let image = PersonImage(uiImage: photo)
		defer {
			ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
			try? Disk.remove(image.cachingKey, from: .caches)
		}
		try Disk.save(photo, to: .caches, as: image.cachingKey)
		let loaded = try await ImagesCache.loadImageFromDiskOrMemory(image: image, directory: .caches)
		XCTAssertTrue(ImagesCache.memoryCache.value(forKey: image.cachingKey) === loaded)
		try Disk.remove(image.cachingKey, from: .caches)
		let cached = try await ImagesCache.loadImageFromDiskOrMemory(image: image, directory: .caches)
		XCTAssertTrue(cached === loaded)
	}

	func testAppAndWidgetPhotosAreStoredAsLosslessPNG() async throws {
		let original = photo()
		let square = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: original.imageRendererFormat).image { _ in
			original.draw(at: CGPoint(x: -100, y: 0))
		}
		for photo in [original, square] {
			let image = PersonImage(uiImage: photo)
			let url = try storedURL(for: image.cachingKey)
			defer {
				ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
				try? FileManager.default.removeItem(at: url)
			}
			try await DiskImageStore().save(image)
			XCTAssertEqual(url.pathExtension, "png")
			let data = try Data(contentsOf: url)
			XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])

			// Evict the saved UIImage so the assertion exercises disk decoding.
			ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
			let decoded = try await ImagesCache.loadImageFromDiskOrMemory(image: PersonImage(id: image.id))
			XCTAssertEqual(try pixels(of: decoded), try pixels(of: photo))
			let thumbnail = try await ImagesCache.loadWidgetImage(image: image)
			XCTAssertEqual(max(thumbnail.size.width, thumbnail.size.height), 256)
		}
	}

	func testLegacyJPEGLoadsInAppAndWidgetAndCanBeDeleted() async throws {
		let image = PersonImage()
		let url = try storedURL(for: image.legacyCachingKey)
		let jpeg = try XCTUnwrap(photo().jpegData(compressionQuality: 0.9))
		try jpeg.write(to: url)
		defer { try? FileManager.default.removeItem(at: url) }

		let decoded = try await ImagesCache.loadImageFromDiskOrMemory(image: image)
		let expected = try XCTUnwrap(UIImage(data: jpeg))
		XCTAssertEqual(try pixels(of: decoded), try pixels(of: expected))
		let thumbnail = try await ImagesCache.loadWidgetImage(image: image)
		XCTAssertEqual(max(thumbnail.size.width, thumbnail.size.height), 256)
		XCTAssertEqual(try Data(contentsOf: url), jpeg)

		try await DiskImageStore().delete(image)
		XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
	}

	func testSavingEditedPhotoPrefersPNGOverLegacyJPEGAndDeletesBoth() async throws {
		let image = PersonImage(uiImage: photo())
		let legacyURL = try storedURL(for: image.legacyCachingKey)
		let pngURL = try storedURL(for: image.cachingKey)
		defer {
			ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
			try? FileManager.default.removeItem(at: legacyURL)
			try? FileManager.default.removeItem(at: pngURL)
		}
		try XCTUnwrap(photo().jpegData(compressionQuality: 0.1)).write(to: legacyURL)
		try await DiskImageStore().save(image)
		ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
		let decoded = try await ImagesCache.loadImageFromDiskOrMemory(image: image)
		XCTAssertEqual(try pixels(of: decoded), try pixels(of: XCTUnwrap(image.uiImage)))
		XCTAssertEqual(ImagesCache.storedCachingKey(for: image), image.cachingKey)

		try await DiskImageStore().delete(image)
		XCTAssertFalse(FileManager.default.fileExists(atPath: pngURL.path))
		XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
	}

	/// An original is written once in a compact format, read back at its full size without the memory cache, and removed
	/// with its picture; a picture saved before originals were kept reads as its own original.
	func testOriginalsAreStoredCompactlyAndLoadAtFullSizeWithoutCaching() async throws {
		let size = CGSize(width: 1200, height: 1600)
		let picked = UIGraphicsImageRenderer(size: size, format: photo().imageRendererFormat).image { context in
			UIColor.red.setFill()
			context.fill(CGRect(origin: .zero, size: size))
			UIColor.blue.setFill()
			context.fill(CGRect(x: 600, y: 800, width: 600, height: 800))
		}
		let image = PersonImage(uiImage: picked)
		let names = OriginalPhotoFile.names(for: image)
		defer { for name in names { try? FileManager.default.removeItem(at: storedURL(for: name)) } }
		try await DiskImageStore().saveOriginal(image)
		let stored = try names.filter { try FileManager.default.fileExists(atPath: storedURL(for: $0).path) }
		let name = try XCTUnwrap(stored.first)
		XCTAssertEqual(stored.count, 1)
		let data = try Data(contentsOf: storedURL(for: name))
		if name == image.originalCachingKey {
			XCTAssertEqual(String(bytes: data[4..<8], encoding: .ascii), "ftyp", "HEIC where the device encodes it")
		} else {
			XCTAssertEqual(name, image.cachingKey)
			XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10], "else lossless PNG")
		}
		XCTAssertNil(ImagesCache.memoryCache.value(forKey: image.cachingKey), "An original is not kept in memory")

		let loaded = try await ImagesCache.loadOriginal(image: PersonImage(id: image.id))
		XCTAssertEqual(loaded.cgImage?.width, 1200, "Full size")
		XCTAssertEqual(loaded.cgImage?.height, 1600)
		XCTAssertNil(ImagesCache.memoryCache.value(forKey: image.cachingKey))
		try await DiskImageStore().delete(image)
		for name in names { XCTAssertFalse(FileManager.default.fileExists(atPath: try storedURL(for: name).path)) }

		let legacy = PersonImage(uiImage: photo())
		defer {
			ImagesCache.memoryCache.removeValue(forKey: legacy.cachingKey)
			try? FileManager.default.removeItem(at: storedURL(for: legacy.cachingKey))
		}
		try await DiskImageStore().save(legacy)
		let legacyOriginal = try await ImagesCache.loadOriginal(image: PersonImage(id: legacy.id))
		XCTAssertEqual(try pixels(of: legacyOriginal), try pixels(of: XCTUnwrap(legacy.uiImage)))
	}

	private func storedURL(for key: String) throws -> URL {
		let directory = try XCTUnwrap(
			FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId))
		return directory.appendingPathComponent(key)
	}

	private func photo() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.preferredRange = .standard
		return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400), format: format).image { context in
			UIColor.red.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
			UIColor.blue.withAlphaComponent(0.5).setFill()
			context.fill(CGRect(x: 300, y: 0, width: 300, height: 200))
		}
	}

	private func pixels(of image: UIImage) throws -> [UInt8] {
		let image = try XCTUnwrap(image.cgImage)
		let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
		let context = try XCTUnwrap(
			CGContext(
				data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
				bytesPerRow: image.width * 4, space: colorSpace,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
		context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
		let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
		return Array(UnsafeBufferPointer(start: bytes, count: image.width * image.height * 4))
	}

	func testThumbnailLoadLeavesTheFullSizeCacheEmpty() async throws {
		let image = PersonImage(uiImage: photo())
		let url = try storedURL(for: image.cachingKey)
		defer {
			ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
			try? FileManager.default.removeItem(at: url)
		}
		try await DiskImageStore().save(image)
		ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
		let thumbnail = try await ImagesCache.loadThumbnail(image: PersonImage(id: image.id), maxPixelSize: 150)
		XCTAssertEqual(try XCTUnwrap(thumbnail.cgImage).width, 150)
		XCTAssertNil(ImagesCache.memoryCache.value(forKey: image.cachingKey), "Only the thumbnail stays in memory")
	}

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

		let image = try await ImagesCache.loadThumbnail(at: url, maxPixelSize: 256)
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
				_ = try await ImagesCache.loadThumbnail(at: url, maxPixelSize: 256)
				XCTFail("Invalid image should use the widget's fallback")
			} catch {
				XCTAssertEqual(error as? CoreError, .missingValue)
			}
		}
		XCTAssertEqual(try Data(contentsOf: url), corrupt)
	}

	func testCancelledWidgetImageLoadPropagatesCancellation() async {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
		let task = Task { try await ImagesCache.loadThumbnail(at: url, maxPixelSize: 256) }
		task.cancel()
		do {
			_ = try await task.value
			XCTFail("Cancelled thumbnail load should not continue")
		} catch {
			XCTAssertTrue(error is CancellationError)
		}
	}
}
