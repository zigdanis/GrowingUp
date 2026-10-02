import Observation
import UIKit

@MainActor
@Observable
final class ImageCaptureCoordinator {
	private(set) var stage: ImageCaptureStage
	private(set) var selectionOrigin: ImageCaptureSelectionOrigin?
	private var cropImage: IdentifiableImage?
	@ObservationIgnored private var pendingSystemPickerImage: UIImage?

	var imageToCrop: IdentifiableImage? {
		get { cropImage }
		set { if newValue == nil { cancelledCrop() } }
	}

	var isSystemPickerPresented: Bool {
		get { stage == .systemPhotoPicker }
		set { if !newValue, stage == .systemPhotoPicker { pickerFinished(with: nil) } }
	}

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

	func pickerFinished(with image: UIImage?) {
		guard stage == .systemPhotoPicker else { return }
		pendingSystemPickerImage = image
		stage = .photoPreview
	}

	func pickerDismissed() {
		guard let image = pendingSystemPickerImage else { return }
		pendingSystemPickerImage = nil
		selectedImage(from: .photoPreview)
		cropImage = IdentifiableImage(image: image)
	}

	func selectedImage(from origin: ImageCaptureSelectionOrigin) {
		selectionOrigin = origin
		stage = origin == .camera ? .camera : .photoPreview
	}

	func cancelledCrop() {
		guard let selectionOrigin else { return }
		cropImage = nil
		stage = selectionOrigin == .camera ? .camera : .photoPreview
		self.selectionOrigin = nil
	}

	func completedCrop() { selectionOrigin = nil }
}
