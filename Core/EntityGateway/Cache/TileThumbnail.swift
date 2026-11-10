import UIKit

/// A mosaic tile's downsized picture, and whether it came ready from the thumbnail cache or had to be decoded from the
/// full-size picture, so the app can tell how often a launch waits for decoding.
public struct TileThumbnail: @unchecked Sendable {
	public let image: UIImage
	public let isFromCache: Bool

	public init(image: UIImage, isFromCache: Bool) {
		self.image = image
		self.isFromCache = isFromCache
	}
}
