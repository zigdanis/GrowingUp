import UIKit

/// Darkens the top and bottom of a widget photo so white text stays readable on any photo.
///
/// The scrims are drawn into the pixels: Tinted and Clear Home Screens render views as alpha masks, where a gradient
/// view would haze the photo, but the photo itself stays full colour in every rendering mode.
enum PhotoScrim {
	private static let topOpacity: CGFloat = 0.35
	private static let bottomOpacity: CGFloat = 0.65

	/// A copy of `image` with the same size and scale, darkened from its vertical centre towards the top and, more, towards the bottom.
	static func apply(to image: UIImage) -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = image.scale
		format.opaque = true
		let bounds = CGRect(origin: .zero, size: image.size)
		return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
			image.draw(in: bounds)
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
