//
//  WorkingImage.swift
//  GrowingUp
//
//  The one way a picked or captured photo enters the app. The photo library, the system picker and the camera hand
//  over the photo's encoded data, and everything after (crop, saving, the widget picture) works only with the
//  image decoded here; originals are never decoded at full size or kept.
//

import ImageIO
import UIKit

enum WorkingImage {
	/// Longest side, in pixels. A standard 12 MP iPhone photo (4032 × 3024) keeps its full detail; larger photos shrink
	/// to this, which still fills the 1800 px main picture after zooming in about 1.7× and is taller than any screen.
	static let maxPixelSide = 4096

	/// Decodes `data` straight to at most `maxPixelSide` pixels on its long side, upright, with its EXIF orientation
	/// applied; smaller photos keep their size. `mirrored` flips it horizontally, so a front-camera photo matches the
	/// mirrored preview. Runs off the main actor.
	@concurrent
	static func decode(_ data: Data, mirrored: Bool = false) async throws -> UIImage {
		try Task.checkCancellation()
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceShouldCacheImmediately: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSide
		]
		guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
			let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
		else { throw CocoaError(.fileReadCorruptFile) }
		let image = UIImage(cgImage: decoded)
		return mirrored ? image.horizontallyMirrored() : image
	}
}
