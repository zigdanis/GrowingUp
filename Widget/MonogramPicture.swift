import UIKit

/// The picture of a person without a photo: a two-tone gradient whose hue stays the same for that person, under their
/// initial as a large watermark.
///
/// It is drawn once into a small standard-range bitmap and then shown like a photo. As an image it stays out of
/// accessibility; a text initial in a tile would be read aloud and would stretch the tile's accessibility frame.
enum MonogramPicture {
	/// The side of the square picture in pixels; widget photos are thumbnails of the same size.
	static let side: CGFloat = 256

	static func draw(id: UUID, name: String) -> UIImage {
		let bounds = CGRect(x: 0, y: 0, width: side, height: side)
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = true
		format.preferredRange = .standard
		return UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
			let hue = hue(for: id)
			let start = UIColor(hue: hue, saturation: 0.6, brightness: 0.82, alpha: 1).cgColor
			let end = UIColor(hue: (hue + 0.8).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.62, alpha: 1).cgColor
			let colors = [start, end] as CFArray
			if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
				context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side, y: side), options: [])
			}
			drawInitial(of: name, in: bounds)
		}
	}

	/// A hue from 0 to 1 derived from the person's id; unlike `hashValue` it is the same on every launch.
	static func hue(for id: UUID) -> Double {
		let hash = withUnsafeBytes(of: id.uuid) { bytes in
			bytes.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
		}
		return Double(hash % 360) / 360
	}

	/// The initial in the top-right corner, large enough to read as a watermark rather than a label.
	private static func drawInitial(of name: String, in bounds: CGRect) {
		let initial = name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).uppercased()
		guard !initial.isEmpty else { return }
		let font = UIFont.systemFont(ofSize: bounds.height * 0.8, weight: .heavy)
		let rounded = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
		let text = NSAttributedString(string: initial, attributes: [.font: rounded, .foregroundColor: UIColor.white.withAlphaComponent(0.22)])
		let size = text.size()
		text.draw(at: CGPoint(x: bounds.maxX - size.width + bounds.width * 0.04, y: bounds.minY - bounds.height * 0.12))
	}
}
