import CoreGraphics

/// Derives a person's widget picture from their main picture: until it is framed by hand, the widget picture shows the
/// main picture's centred square.
public enum WidgetPictureDeriver {
	/// Longest side, in pixels, of a persisted widget picture. The widget never shows it above ~56 pt,
	/// so 480 px covers Retina displays with headroom.
	public static let maxPixelSide: CGFloat = 480

	/// The region of an original photo `size` pixels large that the widget picture shows when the main picture shows
	/// `mainCrop`: the main picture's centred square. The picture itself is rendered from the original, not the main
	/// picture, so it keeps the original's detail.
	public static func crop(centredIn mainCrop: PhotoCrop, ofPhotoSized size: CGSize) -> PhotoCrop {
		let main = mainCrop.rect(in: size)
		let side = min(main.width, main.height)
		let square = CGRect(x: main.midX - side / 2, y: main.midY - side / 2, width: side, height: side)
		return PhotoCrop(square, in: size)
	}
}
