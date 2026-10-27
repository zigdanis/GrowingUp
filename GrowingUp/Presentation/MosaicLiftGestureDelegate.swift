import UIKit

/// Keeps the tile button's own press from preventing its long press on iOS 18. UIKit still fails the long press if
/// the finger moves before the hold, leaving scrolling alone. Once it begins, the mosaic disables finger scrolling
/// and enters reordering, so the button's action cannot open a person on release.
final class MosaicLiftGestureDelegate: NSObject, UIGestureRecognizerDelegate {
	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		true
	}
}
