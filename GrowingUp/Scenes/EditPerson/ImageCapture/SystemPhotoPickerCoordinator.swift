import PhotosUI
import UniformTypeIdentifiers

final class SystemPhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
	let onPicked: (UIImage) -> Void
	let onCancel: () -> Void
	private var isLoading = false
	private var isFinished = false

	init(onPicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
		self.onPicked = onPicked
		self.onCancel = onCancel
	}

	func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
		guard let provider = results.first?.itemProvider else {
			finish(with: nil)
			return
		}
		// One photo at a time; another tap while it loads is ignored.
		guard !isLoading else { return }
		isLoading = true
		showLoading(over: picker)
		_ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
			Task { @MainActor in
				var image: UIImage?
				if let data {
					image = try? await WorkingImage.decode(data)
				}
				self.finish(with: image)
			}
		}
	}

	/// Reports only the first outcome, so a photo that finishes loading after Cancel is dropped.
	private func finish(with image: UIImage?) {
		guard !isFinished else { return }
		isFinished = true
		if let image { onPicked(image) } else { onCancel() }
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
