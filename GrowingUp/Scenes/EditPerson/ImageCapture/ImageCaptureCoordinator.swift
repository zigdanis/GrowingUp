import Observation

@MainActor
@Observable
final class ImageCaptureCoordinator {
	private(set) var stage: ImageCaptureStage
	private(set) var selectionOrigin: ImageCaptureSelectionOrigin?

	init(stage: ImageCaptureStage = .sourceMenu) { self.stage = stage }
	func choseCamera() { stage = .camera }
	func chosePhotos() { stage = .photoPreview }
	func choseAllPhotos() { stage = .systemPhotoPicker }

	func wentBack() {
		switch stage {
		case .camera, .photoPreview: stage = .sourceMenu
		case .systemPhotoPicker: stage = .photoPreview
		case .sourceMenu: break
		}
	}

	func pickerFinishedWithoutImage() { stage = .photoPreview }

	func selectedImage(from origin: ImageCaptureSelectionOrigin) {
		selectionOrigin = origin
		stage = origin == .camera ? .camera : .photoPreview
	}

	func cancelledCrop() {
		guard let selectionOrigin else { return }
		stage = selectionOrigin == .camera ? .camera : .photoPreview
		self.selectionOrigin = nil
	}

	func completedCrop() { selectionOrigin = nil }
}
