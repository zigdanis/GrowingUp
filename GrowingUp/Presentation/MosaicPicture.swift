import UIKit

/// What a person's mosaic tile shows: a downsized photo, or their monogram when no photo loads, with its average colour
/// for the ambient background.
struct MosaicPicture {
	/// The stored picture the image came from; nil for a monogram.
	let pictureID: UUID?
	/// The name a monogram was drawn for, so a renamed person gets a new initial.
	let name: String
	let image: UIImage
	let averageColor: UIColor?
}
