import UIKit

/// Darkens the top and bottom of a widget photo so white text stays readable on any photo.
///
/// The scrims are drawn into the pixels: Tinted and Clear Home Screens render views as alpha masks, where a gradient
/// view would haze the photo, but the photo itself stays full colour in every rendering mode.
enum PhotoScrim {
	private static let topOpacity: CGFloat = 0.35
	private static let bottomOpacity: CGFloat = 0.65

	/// The centred square crop of `image`, at its scale, darkened from its vertical centre towards the top and, more, towards the bottom.
	///
	/// The side is the shorter side of `image`. Widget pictures are stored a pixel off square, and a photo that is not exactly square
	/// would be laid out wider than its tile and widen the tile's accessibility frame.
	static func apply(to image: UIImage) -> UIImage {
		let side = min(image.size.width, image.size.height)
		let bounds = CGRect(x: 0, y: 0, width: side, height: side)
		let format = UIGraphicsImageRendererFormat()
		format.scale = image.scale
		format.opaque = true
		return UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
			let origin = CGPoint(x: (side - image.size.width) / 2, y: (side - image.size.height) / 2)
			image.draw(in: CGRect(origin: origin, size: image.size))
			drawGradient(in: context.cgContext, from: (bounds.minY, topOpacity), to: (bounds.midY, 0))
			drawGradient(in: context.cgContext, from: (bounds.midY, 0), to: (bounds.maxY, bottomOpacity))
		}
	}

	/// Draws black between two heights, with the opacity of each end.
	private static func drawGradient(in context: CGContext, from start: (y: CGFloat, opacity: CGFloat), to end: (y: CGFloat, opacity: CGFloat)) {
		let colors = [start.opacity, end.opacity].map { UIColor.black.withAlphaComponent($0).cgColor } as CFArray
		guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) else { return }
		context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: start.y), end: CGPoint(x: 0, y: end.y), options: [])
	}
}
