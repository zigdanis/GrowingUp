import ImageIO
import UIKit
import UniformTypeIdentifiers

/// How a person's original photo, the uncropped working image the photo was picked as, is written to disk: HEIC at high
/// quality, which keeps a 12-megapixel photo to a few megabytes, else lossless PNG where the device cannot encode HEIC.
/// HEIC compresses with a small, one-time loss: the original is encoded once, when it is picked, and every picture is
/// rendered from it, so the loss never adds up over edits. The pictures the app and the widget show stay PNG.
public enum OriginalPhotoFile {
	/// High quality, at a fraction of PNG's size; not lossless.
	static let quality = 0.9

	/// The file name and contents for the original photo `image`.
	public static func encode(_ image: PersonImage) throws -> (name: String, data: Data) {
		if let pixels = image.uiImage?.cgImage, let heic = encode(pixels, as: .heic) {
			return (image.originalCachingKey, heic)
		}
		guard let png = image.uiImage?.pngData() else { throw CoreError.missingValue }
		return (image.cachingKey, png)
	}

	/// The names `image` may be stored under as an original, most likely first: HEIC, the PNG fallback, and a picture
	/// saved before originals were kept, which serves as its own original.
	public static func names(for image: PersonImage) -> [String] {
		[image.originalCachingKey, image.cachingKey, image.legacyCachingKey]
	}

	private static func encode(_ pixels: CGImage, as type: UTType) -> Data? {
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
		CGImageDestinationAddImage(destination, pixels, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
		return CGImageDestinationFinalize(destination) ? data as Data : nil
	}
}
