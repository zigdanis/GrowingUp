//
//  ImagesCache.swift
//  GrowingUp
//
//  Created by zigdanis on 17/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

@preconcurrency import Disk
import Foundation
import ImageIO
import UIKit

public enum ImagesCache {

	public static let memoryCache = MemoryCache<UIImage>()

	public static func loadImageFromDiskOrMemory(image: PersonImage) async throws -> UIImage {
		try await loadImageFromDiskOrMemory(image: image, directory: .sharedContainer(appGroupName: Constants.appGroupId))
	}

	static func loadImageFromDiskOrMemory(image: PersonImage, directory: Disk.Directory) async throws -> UIImage {
		try Task.checkCancellation()
		let loadedImage = try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				if let memoryImg = memoryCache.value(forKey: image.cachingKey) {
					continuation.resume(returning: memoryImg)
				} else {
					do {
						let key = storedCachingKey(for: image, in: directory)
						let loadedImage = try Disk.retrieve(key, from: directory, as: UIImage.self)
						memoryCache.setValue(loadedImage, forKey: image.cachingKey)
						continuation.resume(returning: loadedImage)
					} catch {
						continuation.resume(throwing: CoreError(error: error))
					}
				}
			}
		}
		try Task.checkCancellation()
		return loadedImage
	}

	/// Decodes only the thumbnail needed by a widget, leaving the original and app cache untouched.
	public static func loadWidgetImage(image: PersonImage) async throws -> UIImage {
		try await loadThumbnail(image: image, maxPixelSize: 256)
	}

	/// Decodes a stored picture straight to a thumbnail whose longer side is at most `maxPixelSize` pixels, leaving the
	/// original and the memory cache of full-size pictures untouched.
	public static func loadThumbnail(image: PersonImage, maxPixelSize: Int) async throws -> UIImage {
		try Task.checkCancellation()
		return try await loadThumbnail(at: storedURL(of: image), maxPixelSize: maxPixelSize)
	}

	/// A mosaic tile's thumbnail of a stored picture, from the thumbnail cache when it holds one; see `ThumbnailCache`.
	public static func loadTileThumbnail(image: PersonImage, maxPixelSize: Int) async throws -> TileThumbnail {
		try Task.checkCancellation()
		return try await ThumbnailCache.shared.thumbnail(of: image.id, maxPixelSize: maxPixelSize, picture: storedURL(of: image))
	}

	/// Where `image` is stored in the App Group, as PNG or as a legacy JPEG.
	private static func storedURL(of image: PersonImage) throws -> URL {
		let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
		return try Disk.url(for: storedCachingKey(for: image, in: directory), in: directory)
	}

	/// Decodes a person's original photo at its full size, upright, without keeping it in the memory cache: it is only
	/// needed while a picture is framed. A picture saved before originals were kept loads as its own original.
	public static func loadOriginal(image: PersonImage) async throws -> UIImage {
		try Task.checkCancellation()
		let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
		guard let name = OriginalPhotoFile.names(for: image).first(where: { Disk.exists($0, in: directory) }) else {
			throw CoreError.missingValue
		}
		return try await loadFullSize(at: Disk.url(for: name, in: directory))
	}

	/// Decodes the picture at `url` at its full size, upright and at once, off the main actor.
	public static func loadFullSize(at url: URL) async throws -> UIImage {
		try await decode(at: url, maxPixelSize: nil, qos: .userInitiated)
	}

	static func storedCachingKey(
		for image: PersonImage, in directory: Disk.Directory = .sharedContainer(appGroupName: Constants.appGroupId)
	) -> String {
		Disk.exists(image.cachingKey, in: directory) ? image.cachingKey : image.legacyCachingKey
	}

	/// Decodes the picture at `url` straight to a thumbnail whose longer side is at most `maxPixelSize` pixels; a smaller
	/// picture keeps its own size. At utility priority unless someone waits for it, as for the mosaic's tiles.
	public static func loadThumbnail(at url: URL, maxPixelSize: Int, qos: DispatchQoS.QoSClass = .utility) async throws -> UIImage {
		try await decode(at: url, maxPixelSize: maxPixelSize, qos: qos)
	}

	/// Decodes the picture at `url` upright, at most `maxPixelSize` pixels on its longer side or else at its own size.
	private static func decode(at url: URL, maxPixelSize: Int?, qos: DispatchQoS.QoSClass) async throws -> UIImage {
		try Task.checkCancellation()
		let thumbnail: UIImage = try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: qos).async {
				let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
				var thumbnailOptions: [CFString: Any] = [
					kCGImageSourceCreateThumbnailFromImageAlways: true,
					kCGImageSourceCreateThumbnailWithTransform: true,
					kCGImageSourceShouldCacheImmediately: true
				]
				// Without a limit, the thumbnail is the whole picture.
				thumbnailOptions[kCGImageSourceThumbnailMaxPixelSize] = maxPixelSize
				guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
					let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
				else {
					continuation.resume(throwing: CoreError.missingValue)
					return
				}
				continuation.resume(returning: UIImage(cgImage: image))
			}
		}
		try Task.checkCancellation()
		return thumbnail
	}

}
