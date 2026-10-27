//
//  WorkingImage.swift
//  GrowingUp
//
//  The one way a picked or captured photo enters the app. The photo library, the system picker and the camera hand
//  over the photo's encoded data, and everything after (crop, saving, the widget picture) works only with the
//  image decoded here. The library's or camera's own file is never decoded at full size or kept; this working image,
//  upright and at most `maxPixelSide` pixels long, is what the app keeps as the person's original photo, uncropped and
//  encoded once (see `OriginalPhotoFile`), so every later framing starts from all of it.
//

import ImageIO
import UIKit

enum WorkingImage {
	/// Longest side, in pixels. A standard 12 MP iPhone photo (4032 × 3024) keeps its full detail; larger photos shrink
	/// to this, which still fills the 1800 px main picture after zooming in about 1.7× and is taller than any screen.
	static let maxPixelSide = 4096

	/// Decodes `data` straight to at most `maxPixelSide` pixels on its long side, upright; smaller photos keep their
	/// size. The data's own EXIF orientation applies unless `orientation` is given: PhotoKit reports it separately,
	/// as a rotation made in Photos can live outside the file. `mirrored` flips it horizontally, so a front-camera
	/// photo matches the mirrored preview. Runs off the main actor.
	@concurrent
	static func decode(
		_ data: Data, orientation: CGImagePropertyOrientation? = nil, mirrored: Bool = false
	) async throws -> UIImage {
		try Task.checkCancellation()
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: orientation == nil,
			kCGImageSourceShouldCacheImmediately: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSide
		]
		guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
			let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
		else { throw CocoaError(.fileReadCorruptFile) }
		var image = UIImage(cgImage: decoded)
		if let orientation, orientation != .up {
			image = upright(decoded, orientation: orientation)
		}
		return mirrored ? image.horizontallyMirrored() : image
	}

	/// Redraws stored pixels turned the way `orientation` says they are shown.
	private static func upright(_ pixels: CGImage, orientation: CGImagePropertyOrientation) -> UIImage {
		let shown = UIImage(cgImage: pixels, scale: 1, orientation: imageOrientation(orientation))
		let format = UIGraphicsImageRendererFormat.default()
		format.scale = 1
		return UIGraphicsImageRenderer(size: shown.size, format: format).image { _ in shown.draw(at: .zero) }
	}

	/// The same orientation for UIKit; both types name their cases alike.
	private static func imageOrientation(_ orientation: CGImagePropertyOrientation) -> UIImage.Orientation {
		switch orientation {
		case .up: return .up
		case .upMirrored: return .upMirrored
		case .down: return .down
		case .downMirrored: return .downMirrored
		case .left: return .left
		case .leftMirrored: return .leftMirrored
		case .right: return .right
		case .rightMirrored: return .rightMirrored
		}
	}
}
