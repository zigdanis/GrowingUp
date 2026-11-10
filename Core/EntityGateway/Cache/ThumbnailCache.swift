import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Keeps the mosaic's tile thumbnails on disk as JPEG, so a cold launch shows the tiles without decoding every full-size
/// picture again.
///
/// A thumbnail is named by its picture's ID and size: a stored picture never changes under its ID, since every new or
/// reframed picture gets a new one, so the name alone tells a thumbnail is current and no modification date is checked.
public struct ThumbnailCache: Sendable {
	/// JPEG at this quality is indistinguishable on a tile, at a fraction of the PNG picture's size.
	static let quality = 0.85

	/// The app's Caches directory: not backed up, and the system may purge it, which only costs a decode on the next
	/// launch.
	public static let shared = ThumbnailCache(
		directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Thumbnails", isDirectory: true))

	let directory: URL

	public init(directory: URL) {
		self.directory = directory
	}

	/// The thumbnail of the picture `id` stored at `picture`, at most `maxPixelSize` pixels on its longer side: the cached
	/// one, or else decoded from `picture` and cached for the next launch.
	///
	/// A picture that is gone takes its thumbnail with it, so a tile never shows a photo the person's page can no longer
	/// show. Both reads run at user-initiated priority: someone is looking at grey tiles meanwhile.
	public func thumbnail(of id: UUID, maxPixelSize: Int, picture: URL) async throws -> TileThumbnail {
		let file = url(of: id, maxPixelSize: maxPixelSize)
		guard FileManager.default.fileExists(atPath: picture.path) else {
			remove(id)
			throw CoreError.missingValue
		}
		if FileManager.default.fileExists(atPath: file.path) {
			do {
				let cached = try await ImagesCache.loadThumbnail(at: file, maxPixelSize: maxPixelSize, qos: .userInitiated)
				return TileThumbnail(image: cached, isFromCache: true)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				// A file that does not decode, such as one cut short, is rewritten below.
			}
		}
		let decoded = try await ImagesCache.loadThumbnail(at: picture, maxPixelSize: maxPixelSize, qos: .userInitiated)
		let thumbnail = TileThumbnail(image: decoded, isFromCache: false)
		await store(thumbnail, at: file)
		return thumbnail
	}

	/// Removes every cached size of the picture `id`.
	public func remove(_ id: UUID) {
		let prefix = id.uuidString + "-"
		let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
		for file in files where file.lastPathComponent.hasPrefix(prefix) {
			try? FileManager.default.removeItem(at: file)
		}
	}

	func url(of id: UUID, maxPixelSize: Int) -> URL {
		directory.appendingPathComponent("\(id.uuidString)-\(maxPixelSize).jpg")
	}

	/// Writes off the main actor and at best effort: a thumbnail that is not written is decoded again next time.
	private func store(_ thumbnail: TileThumbnail, at file: URL) async {
		let directory = directory
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			DispatchQueue.global(qos: .userInitiated).async {
				if let pixels = thumbnail.image.cgImage, let data = Self.encode(pixels) {
					try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
					try? data.write(to: file, options: .atomic)
				}
				continuation.resume()
			}
		}
	}

	/// Encodes the decoded pixels themselves, keeping their colour profile.
	private static func encode(_ pixels: CGImage) -> Data? {
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
			return nil
		}
		CGImageDestinationAddImage(destination, pixels, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
		return CGImageDestinationFinalize(destination) ? data as Data : nil
	}
}
