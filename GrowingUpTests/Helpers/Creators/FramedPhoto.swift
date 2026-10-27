import Core
import UIKit

@testable import GrowingUp

extension FramedPhoto {
	/// `photo` framed whole: the picture is the photo itself, for tests that need no cropping.
	static func whole(_ photo: UIImage) -> FramedPhoto {
		FramedPhoto(source: photo, crop: .whole, picture: photo)
	}
}
