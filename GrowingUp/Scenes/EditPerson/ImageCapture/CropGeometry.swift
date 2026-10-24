import SwiftUI

/// The pan and zoom math of framing a picture on a screen-sized canvas, shared by `CropStep` and the viewer's in-place
/// edit mode.
///
/// At scale 1 and offset zero the picture aspect-fills the canvas, centred. The crop frame must stay covered: the full
/// canvas, or a centred portrait column in wider windows, for the main picture; a circle's square inside the safe area
/// for the widget picture.
struct CropGeometry {
	static let maxZoom: CGFloat = 6
	/// Gap between the circular guide and the safe-area edges.
	static let framePadding: CGFloat = 14
	/// The widest width-to-height ratio of a main picture. iPhone screens and the closed iPhone Duo crop full screen;
	/// wider windows crop a centered column, so every main picture stays portrait.
	static let maxMainAspect: CGFloat = 0.7

	/// The picture's pixel dimensions.
	let pixelSize: CGSize
	let shape: CropShape
	/// The whole canvas, safe areas included, in points.
	let container: CGSize
	let insets: EdgeInsets
	/// Whether the picture must keep the whole canvas covered rather than only the crop frame, as where it is drawn edge
	/// to edge while being framed in place. The crop still takes only the frame.
	let coversWholeCanvas: Bool

	init(pixelSize: CGSize, shape: CropShape, container: CGSize, insets: EdgeInsets, coversWholeCanvas: Bool = false) {
		self.pixelSize = pixelSize
		self.shape = shape
		self.container = container
		self.insets = insets
		self.coversWholeCanvas = coversWholeCanvas
	}

	init(image: UIImage, shape: CropShape, container: CGSize, insets: EdgeInsets, coversWholeCanvas: Bool = false) {
		self.init(
			pixelSize: Self.pixelSize(of: image), shape: shape, container: container, insets: insets, coversWholeCanvas: coversWholeCanvas)
	}

	static func pixelSize(of image: UIImage) -> CGSize {
		if let cgImage = image.cgImage {
			return CGSize(width: cgImage.width, height: cgImage.height)
		}
		return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
	}

	/// Region that stays covered and gets cropped. Rectangle: full screen, or a full-height column centred in windows
	/// wider than `maxMainAspect`. Circle: a square centred in the safe area.
	var frameRect: CGRect {
		guard container.width > 0, container.height > 0 else { return .zero }
		guard shape.isCircular else {
			guard container.width / container.height > Self.maxMainAspect else {
				return CGRect(origin: .zero, size: container)
			}
			let width = container.height * Self.maxMainAspect
			return CGRect(x: (container.width - width) / 2, y: 0, width: width, height: container.height)
		}
		let availX = insets.leading + Self.framePadding
		let availY = insets.top + Self.framePadding
		let availW = max(0, container.width - insets.leading - insets.trailing - Self.framePadding * 2)
		let availH = max(0, container.height - insets.top - insets.bottom - Self.framePadding * 2)
		let side = min(availW, availH)
		guard side > 0 else { return .zero }
		return CGRect(x: availX + (availW - side) / 2, y: availY + (availH - side) / 2, width: side, height: side)
	}

	/// Points per source pixel, so the picture aspect-fills the canvas at scale 1.
	var baseScale: CGFloat {
		guard pixelSize.width > 0, pixelSize.height > 0, container.width > 0, container.height > 0 else { return 1 }
		return max(container.width / pixelSize.width, container.height / pixelSize.height)
	}

	/// The region the picture must keep covered: the whole canvas, or just the crop frame.
	var coveredRect: CGRect {
		coversWholeCanvas ? CGRect(origin: .zero, size: container) : frameRect
	}

	var displaySize: CGSize {
		CGSize(width: pixelSize.width * baseScale, height: pixelSize.height * baseScale)
	}

	/// Smallest zoom that still covers `coveredRect` (limiting side flush to the edge); capped at 1, never zooms in.
	var minScale: CGFloat {
		let display = displaySize
		guard display.width > 0, display.height > 0 else { return 1 }
		let frame = coveredRect
		return min(max(frame.width / display.width, frame.height / display.height), 1)
	}

	/// Allowed offset range per axis so the picture keeps `coveredRect` covered.
	func offsetBounds(scale: CGFloat) -> (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) {
		guard container.width > 0 else { return (0...0, 0...0) }
		let frame = coveredRect
		let display = displaySize
		let deltaX = frame.midX - container.width / 2
		let deltaY = frame.midY - container.height / 2
		let limX = max(0, (display.width * scale - frame.width) / 2)
		let limY = max(0, (display.height * scale - frame.height) / 2)
		return ((deltaX - limX)...(deltaX + limX), (deltaY - limY)...(deltaY + limY))
	}

	func clampOffset(_ proposed: CGSize, scale: CGFloat) -> CGSize {
		let bounds = offsetBounds(scale: scale)
		return CGSize(
			width: min(max(proposed.width, bounds.x.lowerBound), bounds.x.upperBound),
			height: min(max(proposed.height, bounds.y.lowerBound), bounds.y.upperBound)
		)
	}

	/// The nearest scale within the allowed zoom.
	func clampScale(_ proposed: CGFloat) -> CGFloat {
		min(max(proposed, minScale), Self.maxZoom)
	}

	/// Like `clampOffset`, but allows overscroll; the spring snaps it back.
	func rubberBandOffset(_ proposed: CGSize, scale: CGFloat) -> CGSize {
		let bounds = offsetBounds(scale: scale)
		return CGSize(
			width: Self.rubberBand(proposed.width, lower: bounds.x.lowerBound, upper: bounds.x.upperBound, dimension: container.width),
			height: Self.rubberBand(proposed.height, lower: bounds.y.lowerBound, upper: bounds.y.upperBound, dimension: container.height)
		)
	}

	/// Resists pinching below the frame-fill minimum or above `maxZoom`.
	func rubberBandedScale(_ proposed: CGFloat) -> CGFloat {
		let lower = minScale
		if proposed < lower {
			return lower - (lower - proposed) * 0.35
		} else if proposed > Self.maxZoom {
			return Self.maxZoom + (proposed - Self.maxZoom) * 0.35
		}
		return proposed
	}

	/// Standard iOS rubber-band: linear within `[lower, upper]`, asymptotic past.
	static func rubberBand(_ value: CGFloat, lower: CGFloat, upper: CGFloat, dimension: CGFloat) -> CGFloat {
		guard dimension > 0 else { return min(max(value, lower), upper) }
		if value < lower {
			let over = lower - value
			return lower - (1 - 1 / (over / dimension * 0.55 + 1)) * dimension
		} else if value > upper {
			let over = value - upper
			return upper + (1 - 1 / (over / dimension * 0.55 + 1)) * dimension
		}
		return value
	}

	/// The source pixels inside the crop frame at `scale` and `offset`, kept within the picture.
	func cropRect(scale: CGFloat, offset: CGSize) -> CGRect? {
		let pointsPerPixel = baseScale * scale
		guard container.width > 0, pointsPerPixel > 0 else { return nil }
		let frame = frameRect
		let center = CGPoint(x: container.width / 2, y: container.height / 2)
		let cropW = min(frame.width / pointsPerPixel, pixelSize.width)
		let cropH = min(frame.height / pointsPerPixel, pixelSize.height)
		// Picture centred on the canvas at `offset`; the frame may sit off-centre, so map its centre back to source pixels.
		let centerX = pixelSize.width / 2 + (frame.midX - center.x - offset.width) / pointsPerPixel
		let centerY = pixelSize.height / 2 + (frame.midY - center.y - offset.height) / pointsPerPixel
		var rect = CGRect(x: centerX - cropW / 2, y: centerY - cropH / 2, width: cropW, height: cropH)
		rect.origin.x = min(max(0, rect.origin.x), pixelSize.width - rect.width)
		rect.origin.y = min(max(0, rect.origin.y), pixelSize.height - rect.height)
		return rect.integral
	}

	/// The framed part of `image` at the shape's stored size. Cropping only references the source's pixels; scaling them
	/// down redraws, so that runs off the main actor.
	func output(of image: UIImage, scale: CGFloat, offset: CGSize) async -> UIImage {
		let cropped = crop(image, scale: scale, offset: offset)
		let maxPixelSide = shape.maxPixelSize
		return await Task.detached(priority: .userInitiated) { cropped.downsized(maxPixelSide: maxPixelSide) }.value
	}

	/// The source pixels inside the crop frame, at the source's resolution.
	func crop(_ image: UIImage, scale: CGFloat, offset: CGSize) -> UIImage {
		guard let cgImage = image.cgImage, let rect = cropRect(scale: scale, offset: offset),
			let cropped = cgImage.cropping(to: rect)
		else { return image }
		return UIImage(cgImage: cropped, scale: 1, orientation: .up)
	}
}
