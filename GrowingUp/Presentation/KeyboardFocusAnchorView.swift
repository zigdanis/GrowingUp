import UIKit

/// The UIKit side of `KeyboardFocusAnchor`: it becomes first responder once it is in a window.
final class KeyboardFocusAnchorView: UIView {
	override var canBecomeFirstResponder: Bool { true }

	override func didMoveToWindow() {
		super.didMoveToWindow()
		accessibilityElementsHidden = true
		guard window != nil else { return }
		// On the next turn of the run loop, once a presentation has placed the view, as a window takes only a view it shows.
		DispatchQueue.main.async { [weak self] in
			_ = self?.becomeFirstResponder()
		}
	}
}
