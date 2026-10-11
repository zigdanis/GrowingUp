//
//  ImagesCache.swift
//  GrowingUp
//
//  Created by zigdanis on 17/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Disk
import Foundation
import ImageIO
import UIKit

public enum ImagesCache {

	public static let memoryCache = MemoryCache<UIImage>()

	public static func loadImageFromDiskOrMemory(image: PersonImage) async throws -> UIImage {
		try Task.checkCancellation()
		let loadedImage = try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				if let memoryImg = memoryCache.value(forKey: image.cachingKey) {
					continuation.resume(returning: memoryImg)
				} else {
					let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
					do {
						continuation.resume(
							returning: try Disk.retrieve(image.cachingKey, from: directory, as: UIImage.self))
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
		try Task.checkCancellation()
		let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
		let url = try Disk.url(for: image.cachingKey, in: directory)
		return try await loadWidgetImage(at: url)
	}

	static func loadWidgetImage(at url: URL) async throws -> UIImage {
		try Task.checkCancellation()
		let thumbnail: UIImage = try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .utility).async {
				let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
				let thumbnailOptions: [CFString: Any] = [
					kCGImageSourceCreateThumbnailFromImageAlways: true,
					kCGImageSourceCreateThumbnailWithTransform: true,
					kCGImageSourceShouldCacheImmediately: true,
					kCGImageSourceThumbnailMaxPixelSize: 256
				]
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
