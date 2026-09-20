import PhotosUI

final class SystemPhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
	let onPicked: (UIImage) -> Void
	let onCancel: () -> Void

	init(onPicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
		self.onPicked = onPicked
		self.onCancel = onCancel
	}

	func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
		guard let provider = results.first?.itemProvider else {
			onCancel()
			return
		}
		provider.loadObject(ofClass: UIImage.self) { [onPicked, onCancel] object, _ in
			DispatchQueue.main.async {
				if let image = object as? UIImage { onPicked(image) } else { onCancel() }
			}
		}
	}
}
