import UIKit

/// Derives a person's widget picture from their main photo.
public enum WidgetPictureDeriver {
	/// Longest side, in pixels, of a persisted widget picture. The widget never shows it above ~56 pt,
	/// so 480 px covers Retina displays with headroom.
	public static let maxPixelSide: CGFloat = 480

	/// Returns the centered square of `image`, downscaled to at most `maxPixelSide` pixels per side.
	/// Drawing through `UIImage` applies its orientation, so the result is always upright.
	public static func derive(from image: UIImage) -> UIImage {
		let pixelWidth = image.size.width * image.scale
		let pixelHeight = image.size.height * image.scale
		let side = min(pixelWidth, pixelHeight)
		guard side > 0 else { return image }
		let target = max(1, min(side, maxPixelSide).rounded())
		let ratio = target / side
		let drawnSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)
		let origin = CGPoint(x: (target - drawnSize.width) / 2, y: (target - drawnSize.height) / 2)
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = true
		format.preferredRange = .standard
		let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
		return renderer.image { _ in
			image.draw(in: CGRect(origin: origin, size: drawnSize))
		}
	}
}
