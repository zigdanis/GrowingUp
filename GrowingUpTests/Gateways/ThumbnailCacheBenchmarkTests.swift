import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest

@testable import Core

/// Times the mosaic's tile thumbnails for eight photo-sized pictures, loaded one after another as the mosaic loads them:
/// decoded from the full-size PNG as before the thumbnail cache, on a first launch that fills the cache, and read back
/// from the filled cache. It runs only on request, as it takes a while and its timings depend on the machine:
/// `TEST_RUNNER_GROWINGUP_BENCHMARK=1 xcodebuild test -only-testing:GrowingUpTests/ThumbnailCacheBenchmarkTests …`,
/// then `grep THUMBNAIL_BENCHMARK` in the output. `xcodebuild` hands the tests a `TEST_RUNNER_` variable without that
/// prefix, so the test reads `GROWINGUP_BENCHMARK`.
@MainActor
final class ThumbnailCacheBenchmarkTests: XCTestCase {
	private static let pictureCount = 8
	private static let rounds = 5
	private static let maxPixelSize = 960
	private static let pictureSize = (width: 1350, height: 1800)

	func testTileThumbnailTimings() async throws {
		try XCTSkipUnless(ProcessInfo.processInfo.environment["GROWINGUP_BENCHMARK"] == "1", "Set GROWINGUP_BENCHMARK=1 to run")
		let root = FileManager.default.temporaryDirectory.appendingPathComponent("ThumbnailBenchmark-\(UUID().uuidString)", isDirectory: true)
		defer { try? FileManager.default.removeItem(at: root) }
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		let cacheDirectory = root.appendingPathComponent("Thumbnails", isDirectory: true)
		let cache = ThumbnailCache(directory: cacheDirectory)
		let pictures = try (0..<Self.pictureCount).map { index in
			let id = UUID()
			let url = root.appendingPathComponent(id.uuidString + ".png")
			try Self.photoLikePNG(seed: UInt64(index + 1)).write(to: url)
			return (id: id, url: url)
		}

		let before = try await timeRounds {
			for picture in pictures {
				let image = try await ImagesCache.loadThumbnail(at: picture.url, maxPixelSize: Self.maxPixelSize)
				XCTAssertNotNil(image.cgImage)
			}
		}
		let firstLaunch = try await timeRounds {
			try? FileManager.default.removeItem(at: cacheDirectory)
			for picture in pictures {
				let thumbnail = try await cache.thumbnail(of: picture.id, maxPixelSize: Self.maxPixelSize, picture: picture.url)
				XCTAssertFalse(thumbnail.isFromCache)
				XCTAssertNotNil(thumbnail.image.cgImage)
			}
		}
		let after = try await timeRounds {
			for picture in pictures {
				let thumbnail = try await cache.thumbnail(of: picture.id, maxPixelSize: Self.maxPixelSize, picture: picture.url)
				XCTAssertTrue(thumbnail.isFromCache, "The cache was filled by the first-launch rounds")
				XCTAssertNotNil(thumbnail.image.cgImage)
			}
		}

		Self.report("before", before)
		Self.report("after_first_launch", firstLaunch)
		Self.report("after", after)
		let pngBytes = try pictures.map { try Self.fileSize(of: $0.url) }
		let jpegBytes = try pictures.map { try Self.fileSize(of: cache.url(of: $0.id, maxPixelSize: Self.maxPixelSize)) }
		print(
			"THUMBNAIL_BENCHMARK sizes png_avg_kb=\(pngBytes.reduce(0, +) / pngBytes.count / 1024)"
				+ " jpeg_avg_kb=\(jpegBytes.reduce(0, +) / jpegBytes.count / 1024) pictures=\(Self.pictureCount)")
	}

	/// The milliseconds each of the rounds of `work` took.
	private func timeRounds(_ work: () async throws -> Void) async throws -> [Double] {
		let clock = ContinuousClock()
		var timings: [Double] = []
		for _ in 0..<Self.rounds {
			let start = clock.now
			try await work()
			let elapsed = (clock.now - start).components
			timings.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
		}
		return timings
	}

	private static func report(_ variant: String, _ timings: [Double]) {
		let sorted = timings.sorted()
		let format = { (value: Double) in String(format: "%.1f", value) }
		print(
			"THUMBNAIL_BENCHMARK \(variant) median=\(format(sorted[sorted.count / 2])) ms min=\(format(sorted[0]))"
				+ " max=\(format(sorted[sorted.count - 1])) rounds=\(sorted.count) pictures=\(pictureCount)")
	}

	private static func fileSize(of url: URL) throws -> Int {
		try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
	}

	/// A PNG that costs about what a photo costs to decode: gradients under per-pixel noise, which PNG cannot compress
	/// away as it does flat colour; the same `seed` always gives the same picture.
	private static func photoLikePNG(seed: UInt64) throws -> Data {
		let (width, height) = pictureSize
		let bytesPerRow = width * 4
		var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
		var state = seed &* 0x9E37_79B9_7F4A_7C15
		pixels.withUnsafeMutableBufferPointer { buffer in
			for row in 0..<height {
				for column in 0..<width {
					// xorshift64: cheap, deterministic noise.
					state ^= state << 13
					state ^= state >> 7
					state ^= state << 17
					let noise = Int(state & 0x3F) - 32
					let offset = row * bytesPerRow + column * 4
					buffer[offset] = UInt8(clamping: column * 255 / width + noise)
					buffer[offset + 1] = UInt8(clamping: row * 255 / height + noise / 2)
					buffer[offset + 2] = UInt8(clamping: (column + row + Int(seed) * 97) % 256 + noise)
				}
			}
		}
		let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
		let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
		let image = try XCTUnwrap(
			CGImage(
				width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: colorSpace,
				bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider, decode: nil,
				shouldInterpolate: false, intent: .defaultIntent))
		let data = NSMutableData()
		let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
		CGImageDestinationAddImage(destination, image, nil)
		XCTAssertTrue(CGImageDestinationFinalize(destination))
		return data as Data
	}
}
