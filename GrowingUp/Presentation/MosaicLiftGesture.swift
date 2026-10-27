import SwiftUI
import UIKit

/// The press that lifts a mosaic tile, as UIKit's own reordering does: a press held still for `minimumDuration` lifts
/// the tile, and the same touch then carries it until the finger lets go.
///
/// It is UIKit's long press rather than a SwiftUI long press sequenced before a drag. That drag, armed from the first
/// touch, kept the mosaic from scrolling when a swipe started on a tile. A UIKit long press fails as soon as the finger
/// moves before it is due, which leaves the swipe to the scroll view; once it has lifted the tile, it alone follows the
/// finger.
struct MosaicLiftGesture: UIGestureRecognizerRepresentable {
	let minimumDuration: TimeInterval
	/// Where the finger is reported: the mosaic's scroll content.
	let coordinateSpace: NamedCoordinateSpace
	/// The press lifted the tile under the finger at this point.
	let onLift: (CGPoint) -> Void
	/// The finger carrying the lifted tile moved to this point.
	let onMove: (CGPoint) -> Void
	/// The finger let go, or the system took the touch away.
	let onRelease: () -> Void

	func makeCoordinator(converter: CoordinateSpaceConverter) -> MosaicLiftGestureDelegate {
		MosaicLiftGestureDelegate()
	}

	func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
		let recognizer = UILongPressGestureRecognizer()
		recognizer.minimumPressDuration = minimumDuration
		recognizer.delegate = context.coordinator
		return recognizer
	}

	func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
		recognizer.minimumPressDuration = minimumDuration
	}

	func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
		let location = context.converter.location(in: coordinateSpace)
		switch recognizer.state {
		case .began: onLift(location)
		case .changed: onMove(location)
		case .ended, .cancelled: onRelease()
		default: break
		}
	}
}
