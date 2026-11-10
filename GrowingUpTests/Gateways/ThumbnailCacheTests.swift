import ImageIO
import UIKit
import XCTest

@testable import Core

/// Tile thumbnails are decoded once, kept as JPEG and read back on later launches; they leave with their picture.
@MainActor
final class ThumbnailCacheTests: XCTestCase {
	private var root: URL!
	private var cache: ThumbnailCache!

	override func setUpWithError() throws {
		root = FileManager.default.temporaryDirectory.appendingPathComponent("ThumbnailCacheTests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		cache = ThumbnailCache(directory: root.appendingPathComponent("Thumbnails", isDirectory: true))
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: root)
	}

	func testAMissDecodesAndCachesAJPEGThatTheNextLoadReads() async throws {
		let id = UUID()
		let picture = try storePicture(id, size: CGSize(width: 1200, height: 1600))
		let first = try await cache.thumbnail(of: id, maxPixelSize: 400, picture: picture)
		XCTAssertFalse(first.isFromCache)
		XCTAssertEqual(try pixelSize(of: first.image), [300, 400])
		let file = cache.url(of: id, maxPixelSize: 400)
		XCTAssertEqual(Array(try Data(contentsOf: file).prefix(3)), [0xFF, 0xD8, 0xFF], "Stored as JPEG")
		XCTAssertEqual(try storedPixelSize(of: file), [300, 400])

		let second = try await cache.thumbnail(of: id, maxPixelSize: 400, picture: picture)
		XCTAssertTrue(second.isFromCache)
		XCTAssertEqual(try pixelSize(of: second.image), [300, 400])
	}

	func testAMissingPictureThrowsAndTakesItsThumbnailAlong() async throws {
		let id = UUID()
		let picture = try storePicture(id, size: CGSize(width: 600, height: 400))
		_ = try await cache.thumbnail(of: id, maxPixelSize: 200, picture: picture)
		let file = cache.url(of: id, maxPixelSize: 200)
		XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
		try FileManager.default.removeItem(at: picture)
		do {
			_ = try await cache.thumbnail(of: id, maxPixelSize: 200, picture: picture)
			XCTFail("A removed picture shows no tile photo")
		} catch {
			XCTAssertEqual(error as? CoreError, .missingValue)
		}
		XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
	}

	func testACorruptThumbnailIsDecodedAgainAndReplaced() async throws {
		let id = UUID()
		let picture = try storePicture(id, size: CGSize(width: 600, height: 400))
		let file = cache.url(of: id, maxPixelSize: 200)
		try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data("not a jpeg".utf8).write(to: file)
		let repaired = try await cache.thumbnail(of: id, maxPixelSize: 200, picture: picture)
		XCTAssertFalse(repaired.isFromCache)
		XCTAssertEqual(try pixelSize(of: repaired.image), [200, 133])
		XCTAssertEqual(try storedPixelSize(of: file), [200, 133])
		let cached = try await cache.thumbnail(of: id, maxPixelSize: 200, picture: picture)
		XCTAssertTrue(cached.isFromCache)
	}

	func testRemoveDeletesEverySizeOfOnePictureOnly() async throws {
		let removed = UUID()
		let kept = UUID()
		let removedPicture = try storePicture(removed, size: CGSize(width: 600, height: 400))
		let keptPicture = try storePicture(kept, size: CGSize(width: 600, height: 400))
		for size in [100, 200] { _ = try await cache.thumbnail(of: removed, maxPixelSize: size, picture: removedPicture) }
		_ = try await cache.thumbnail(of: kept, maxPixelSize: 100, picture: keptPicture)
		cache.remove(removed)
		XCTAssertFalse(FileManager.default.fileExists(atPath: cache.url(of: removed, maxPixelSize: 100).path))
		XCTAssertFalse(FileManager.default.fileExists(atPath: cache.url(of: removed, maxPixelSize: 200).path))
		XCTAssertTrue(FileManager.default.fileExists(atPath: cache.url(of: kept, maxPixelSize: 100).path))
		cache.remove(UUID())
		ThumbnailCache(directory: root.appendingPathComponent("Missing", isDirectory: true)).remove(kept)
	}

	func testASmallPictureKeepsItsOwnSize() async throws {
		let id = UUID()
		let picture = try storePicture(id, size: CGSize(width: 300, height: 200))
		let decoded = try await cache.thumbnail(of: id, maxPixelSize: 960, picture: picture)
		XCTAssertEqual(try pixelSize(of: decoded.image), [300, 200], "Never scaled up")
		let cached = try await cache.thumbnail(of: id, maxPixelSize: 960, picture: picture)
		XCTAssertTrue(cached.isFromCache)
		XCTAssertEqual(try pixelSize(of: cached.image), [300, 200])
	}

	/// Writes a two-colour PNG picture like the app stores, and returns its URL.
	private func storePicture(_ id: UUID, size: CGSize) throws -> URL {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.preferredRange = .standard
		let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
			UIColor.red.setFill()
			context.fill(CGRect(origin: .zero, size: size))
			UIColor.blue.setFill()
			context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2))
		}
		let url = root.appendingPathComponent(id.uuidString + ".png")
		try XCTUnwrap(image.pngData()).write(to: url)
		return url
	}

	private func pixelSize(of image: UIImage) throws -> [Int] {
		let pixels = try XCTUnwrap(image.cgImage)
		return [pixels.width, pixels.height]
	}

	private func storedPixelSize(of file: URL) throws -> [Int] {
		let source = try XCTUnwrap(CGImageSourceCreateWithURL(file as CFURL, nil))
		let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
		return [try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int), try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int)]
	}
}
