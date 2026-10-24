import CoreGraphics

/// How the main photo sits on the edit-mode canvas: its zoom and its offset from centred, both relative to the photo
/// aspect-filling the canvas, as in `CropGeometry`.
struct PhotoFraming: Equatable {
	/// The photo as the viewer shows it: aspect-filling the window, centred.
	static let identity = PhotoFraming(scale: 1, offset: .zero)

	var scale: CGFloat
	var offset: CGSize
}
