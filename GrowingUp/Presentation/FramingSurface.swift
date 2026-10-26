import SwiftUI

/// The edit mode's photo gestures, on a UIKit surface over the photo; see `FramingSurfaceView` for why they are not
/// SwiftUI gestures.
struct FramingSurface: UIViewRepresentable {
	let onDrag: (CGSize) -> Void
	let onDragEnd: () -> Void
	let onPinch: (CGFloat) -> Void
	let onPinchEnd: () -> Void
	let onDoubleTap: () -> Void

	func makeUIView(context: Context) -> FramingSurfaceView {
		FramingSurfaceView()
	}

	func updateUIView(_ surface: FramingSurfaceView, context: Context) {
		surface.onDrag = onDrag
		surface.onDragEnd = onDragEnd
		surface.onPinch = onPinch
		surface.onPinchEnd = onPinchEnd
		surface.onDoubleTap = onDoubleTap
	}
}
