import Observation
import UIKit

@MainActor
@Observable
final class ImageCaptureCoordinator {
	private(set) var stage: ImageCaptureStage
	private var cropImage: IdentifiableImage?
	@ObservationIgnored private var selectionOrigin: ImageCaptureSelectionOrigin?
	@ObservationIgnored private var pendingSystemPickerImage: UIImage?
	@ObservationIgnored private var pendingFramedPhoto: FramedPhoto?

	var imageToCrop: IdentifiableImage? {
		get { cropImage }
		set { if newValue == nil { cancelledCrop() } }
	}

	var isSystemPickerPresented: Bool {
		get { stage == .systemPhotoPicker }
		set { if !newValue, stage == .systemPhotoPicker { pickerFinished(with: nil) } }
	}

	init(stage: ImageCaptureStage) { self.stage = stage }
	func choseAllPhotos() { stage = .systemPhotoPicker }

	/// Steps back one level. Returns true when Back leaves the flow, from the camera or the photo preview it opened on.
	func wentBack() -> Bool {
		switch stage {
		case .camera, .photoPreview: return true
		case .systemPhotoPicker:
			stage = .photoPreview
			return false
		}
	}

	func pickerFinished(with image: UIImage?) {
		guard stage == .systemPhotoPicker else { return }
		pendingSystemPickerImage = image
		stage = .photoPreview
	}

	func pickerDismissed() {
		guard let image = pendingSystemPickerImage else { return }
		pendingSystemPickerImage = nil
		selectedImage(image, from: .photoPreview)
	}

	func selectedImage(_ image: UIImage, from origin: ImageCaptureSelectionOrigin) {
		selectionOrigin = origin
		stage = origin == .camera ? .camera : .photoPreview
		cropImage = IdentifiableImage(image: image)
	}

	func cancelledCrop() {
		guard let selectionOrigin else { return }
		cropImage = nil
		stage = selectionOrigin == .camera ? .camera : .photoPreview
		self.selectionOrigin = nil
	}

	func completedCrop(with framed: FramedPhoto) {
		guard cropImage != nil else { return }
		pendingFramedPhoto = framed
		cropImage = nil
		selectionOrigin = nil
	}

	func cropDismissed() -> FramedPhoto? {
		defer { pendingFramedPhoto = nil }
		return pendingFramedPhoto
	}
}
