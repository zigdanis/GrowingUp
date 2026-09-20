import PhotosUI
import SwiftUI

struct SystemPhotoPicker: UIViewControllerRepresentable {
	let onPicked: (UIImage) -> Void
	let onCancel: () -> Void

	func makeCoordinator() -> SystemPhotoPickerCoordinator {
		SystemPhotoPickerCoordinator(onPicked: onPicked, onCancel: onCancel)
	}

	func makeUIViewController(context: Context) -> PHPickerViewController {
		var configuration = PHPickerConfiguration(photoLibrary: .shared())
		configuration.filter = .images
		configuration.selectionLimit = 1
		let picker = PHPickerViewController(configuration: configuration)
		picker.delegate = context.coordinator
		return picker
	}

	func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
