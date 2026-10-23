import PhotosUI
import UniformTypeIdentifiers

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
		showLoading(over: picker)
		_ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [onPicked, onCancel] data, _ in
			Task { @MainActor in
				if let data, let image = try? await WorkingImage.decode(data) { onPicked(image) } else { onCancel() }
			}
		}
	}

	/// A spinner over the picker while the picked photo loads and decodes. Touches still reach the picker, so Cancel
	/// keeps working; dismissing the picker removes the spinner.
	private func showLoading(over picker: PHPickerViewController) {
		let spinner = UIActivityIndicatorView(style: .large)
		spinner.frame = picker.view.bounds
		spinner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		spinner.backgroundColor = UIColor.black.withAlphaComponent(0.25)
		spinner.color = .white
		spinner.isUserInteractionEnabled = false
		spinner.startAnimating()
		picker.view.addSubview(spinner)
	}
}
