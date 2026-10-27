import Core
import UIKit

/// A picture framed from a photo: the photo, the region of it the picture shows, and the picture rendered from that
/// region at its slot's stored size. The photo stays whole, so the picture can be framed again from all of it.
struct FramedPhoto {
	let source: UIImage
	let crop: PhotoCrop
	let picture: UIImage
}
