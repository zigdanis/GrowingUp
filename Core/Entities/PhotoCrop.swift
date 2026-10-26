import CoreGraphics

/// The region of a person's original photo that one of their pictures shows, in unit coordinates of the photo: it spans
/// 0 to 1 across and down whatever its pixel size, so the region outlasts the photo being decoded again.
///
/// Every picture is rendered from the original through its own region, never from another picture, so framing a picture
/// again starts from the whole photo and loses no pixels.
public struct PhotoCrop: Hashable, Sendable {
	/// The whole photo, the region of a picture picked before originals were kept, which serves as its own original.
	public static let whole = PhotoCrop(minX: 0, minY: 0, width: 1, height: 1)

	/// The region's leading edge, as a fraction of the photo's width.
	public var minX: Double
	/// The region's top edge, as a fraction of the photo's height.
	public var minY: Double
	public var width: Double
	public var height: Double

	public init(minX: Double, minY: Double, width: Double, height: Double) {
		self.minX = minX
		self.minY = minY
		self.width = width
		self.height = height
	}

	/// The region `rect`, in pixels of a photo `size` pixels large.
	public init(_ rect: CGRect, in size: CGSize) {
		self.init(
			minX: rect.minX / size.width, minY: rect.minY / size.height, width: rect.width / size.width,
			height: rect.height / size.height)
	}

	/// The region in pixels of a photo `size` pixels large.
	public func rect(in size: CGSize) -> CGRect {
		CGRect(x: minX * size.width, y: minY * size.height, width: width * size.width, height: height * size.height)
	}

	// MARK: - Storage

	/// The four numbers, comma-separated, each as Swift writes a `Double`, which reads back to the same value.
	public var storedValue: String {
		[minX, minY, width, height].map { String($0) }.joined(separator: ",")
	}

	/// Reads `storedValue`; nil without one, or for a malformed or empty region.
	public init?(storedValue: String?) {
		let numbers = storedValue?.split(separator: ",").compactMap { Double($0) } ?? []
		guard numbers.count == 4, numbers.allSatisfy(\.isFinite), numbers[2] > 0, numbers[3] > 0 else { return nil }
		self.init(minX: numbers[0], minY: numbers[1], width: numbers[2], height: numbers[3])
	}
}
