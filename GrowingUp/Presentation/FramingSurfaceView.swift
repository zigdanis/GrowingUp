import UIKit

/// The edit mode's photo as a UIKit surface: one finger moves the photo, two pinch it, and a double tap puts it back.
///
/// The viewer opens with a zoom transition, whose pinch to close sits on the cover above the photo. Edit mode disables
/// closing, yet that pinch still claimed every inward pinch, so the photo zoomed in but never back out. UIKit asks the
/// view under the fingers whether another view's gesture may begin, so this view declines every gesture that is not its
/// own: whatever starts on the photo while editing frames it.
final class FramingSurfaceView: UIView, UIGestureRecognizerDelegate {
	/// The finger's travel since the drag began.
	var onDrag: (CGSize) -> Void = { _ in }
	var onDragEnd: () -> Void = {}
	/// The fingers' spread since the pinch began, 1 at its start.
	var onPinch: (CGFloat) -> Void = { _ in }
	var onPinchEnd: () -> Void = {}
	var onDoubleTap: () -> Void = {}

	override init(frame: CGRect) {
		super.init(frame: frame)
		let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
		doubleTap.numberOfTapsRequired = 2
		let recognizers = [
			UIPanGestureRecognizer(target: self, action: #selector(panned)),
			UIPinchGestureRecognizer(target: self, action: #selector(pinched)),
			doubleTap
		]
		for recognizer in recognizers {
			recognizer.delegate = self
			addGestureRecognizer(recognizer)
		}
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("FramingSurfaceView is created in code only")
	}

	/// Asked for this view's own gestures, and for those of the views above it whose touches start here.
	override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		gestureRecognizer.view === self && super.gestureRecognizerShouldBegin(gestureRecognizer)
	}

	/// Moving and pinching go together, as two fingers on a photo do.
	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		gestureRecognizer.view === self && otherGestureRecognizer.view === self
	}

	@objc
	private func panned(_ recognizer: UIPanGestureRecognizer) {
		switch recognizer.state {
		case .began, .changed:
			let translation = recognizer.translation(in: self)
			onDrag(CGSize(width: translation.x, height: translation.y))
		case .ended, .cancelled:
			onDragEnd()
		default:
			break
		}
	}

	@objc
	private func pinched(_ recognizer: UIPinchGestureRecognizer) {
		switch recognizer.state {
		case .began, .changed:
			onPinch(recognizer.scale)
		case .ended, .cancelled:
			onPinchEnd()
		default:
			break
		}
	}

	@objc
	private func doubleTapped() {
		onDoubleTap()
	}
}
