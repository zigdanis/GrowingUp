import Photos
import UIKit

/// A single photo-library asset, adapted for SwiftUI identity.
struct PhotoAsset: Identifiable, Equatable {
	let id: String
	let asset: PHAsset?
	let previewImage: UIImage?

	init(_ asset: PHAsset) {
		id = asset.localIdentifier
		self.asset = asset
		previewImage = nil
	}

	init(previewImage: UIImage) {
		id = UUID().uuidString
		asset = nil
		self.previewImage = previewImage
	}

	static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
