import CoreGraphics
import Foundation

/// A mosaic tile lifted for reordering, whose floating copy follows the finger through the mosaic's scroll content.
struct MosaicDrag: Equatable {
	let id: UUID
	/// The finger in the scroll content; nil from the lift until the finger first moves.
	var location: CGPoint?
	/// The finger's offset from the floating tile's corner, kept from the first move on.
	var grab: CGSize?
	/// Whether the finger let go and the floating copy glides into the tile's slot.
	var isSettling = false

	/// Follows the finger at `location`, which started the drag at `start` over the tile whose slot is at `slotOrigin`.
	mutating func follow(to location: CGPoint, from start: CGPoint, slotOrigin: CGPoint) {
		if grab == nil {
			grab = CGSize(width: start.x - slotOrigin.x, height: start.y - slotOrigin.y)
		}
		self.location = location
	}

	/// The floating tile's corner: under the finger while dragging, otherwise on the tile's slot at `slotOrigin`.
	func origin(slotOrigin: CGPoint) -> CGPoint {
		guard !isSettling, let location, let grab else { return slotOrigin }
		return CGPoint(x: location.x - grab.width, y: location.y - grab.height)
	}
}
