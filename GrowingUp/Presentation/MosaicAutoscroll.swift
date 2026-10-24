import SwiftUI

/// How the reordering mosaic scrolls while a dragged tile is held near its top or bottom edge: faster the nearer the
/// finger is to the edge, and never past the content.
///
/// Fingers and the visible mosaic are in the scroll content's coordinates, as the drag reports them; scroll positions
/// are in `ScrollPosition`'s, counted from the top inset's edge.
struct MosaicAutoscroll: Equatable {
	/// How far into the visible mosaic its edges start scrolling a dragged tile's way.
	static let zone: CGFloat = 80
	/// The speed at the very edge, in points per second; the zone's inner edge scrolls at 15% of it.
	static let speed: CGFloat = 900
	/// How long a dragged tile waits near an edge before the mosaic scrolls, so a tile dropped near an edge lands where it
	/// was dropped.
	static let delay = Duration.milliseconds(250)

	/// The mosaic's visible part, clear of the bars and the floating button that the insets cover.
	let visible: ClosedRange<CGFloat>
	/// The positions the mosaic can scroll to: just one when its content fits.
	let positions: ClosedRange<CGFloat>
	let position: CGFloat

	init(_ geometry: ScrollGeometry) {
		// The visible rect spans the whole scroll view, under the bars and the button that the insets cover.
		let top = geometry.visibleRect.minY + geometry.contentInsets.top
		let bottom = geometry.visibleRect.maxY - geometry.contentInsets.bottom
		visible = top...max(top, bottom)
		// Content offsets count from the top inset, which the scroll position does not.
		let insets = geometry.contentInsets.top + geometry.contentInsets.bottom
		positions = 0...max(0, geometry.contentSize.height + insets - geometry.visibleRect.height)
		position = geometry.contentOffset.y + geometry.contentInsets.top
	}

	/// -1 or 1 while the finger at `location` is near the top or bottom edge, which scrolls the mosaic that way; otherwise 0.
	func direction(at location: CGPoint) -> Int {
		if location.y < visible.lowerBound + Self.zone { return -1 }
		if location.y > visible.upperBound - Self.zone { return 1 }
		return 0
	}

	/// The scroll position after `interval` of scrolling with the finger at `location`; nil when the finger is clear of the
	/// edges or the mosaic cannot scroll further that way.
	func position(after interval: TimeInterval, location: CGPoint) -> CGFloat? {
		let direction = direction(at: location)
		guard direction != 0 else { return nil }
		let depth = direction < 0 ? visible.lowerBound + Self.zone - location.y : location.y - visible.upperBound + Self.zone
		let speed = Self.speed * min(max(depth / Self.zone, 0.15), 1)
		let step = CGFloat(direction) * speed * CGFloat(interval)
		let next = min(max(position + step, positions.lowerBound), positions.upperBound)
		return next == position ? nil : next
	}
}
