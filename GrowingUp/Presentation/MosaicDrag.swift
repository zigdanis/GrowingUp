import CoreGraphics
import Foundation

/// A mosaic tile lifted for reordering, whose floating copy follows the finger through the mosaic's scroll content.
struct MosaicDrag: Equatable {
	let id: UUID
	/// The finger in the scroll content; nil from the lift until the finger is first reported.
	var location: CGPoint?
	/// The finger's offset from the floating tile's corner, kept from where the press lifted the tile.
	var grab: CGSize?
	/// Whether the finger let go and the floating copy glides into the tile's slot.
	var isSettling = false

	/// Follows the finger at `location` over the tile whose slot is at `slotOrigin`; the first location, where the press
	/// lifted the tile, sets where the finger holds it.
	mutating func follow(to location: CGPoint, slotOrigin: CGPoint) {
		if grab == nil {
			grab = CGSize(width: location.x - slotOrigin.x, height: location.y - slotOrigin.y)
		}
		self.location = location
	}

	/// The floating tile's corner: under the finger while dragging, otherwise on the tile's slot at `slotOrigin`.
	func origin(slotOrigin: CGPoint) -> CGPoint {
		guard !isSettling, let location, let grab else { return slotOrigin }
		return CGPoint(x: location.x - grab.width, y: location.y - grab.height)
	}
}
