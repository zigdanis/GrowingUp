import SwiftUI

struct ImageCaptureFlowView: View {
	let cropShape: CropShape
	let previewImages: [UIImage]?
	let onComplete: (UIImage) -> Void
	let onCancel: () -> Void
	@Environment(\.scenePhase)
	private var scenePhase
	@State private var coordinator: ImageCaptureCoordinator
	@State private var cameraModel = CameraSourceModel()
	@State private var selectedImage: IdentifiableImage?
	@State private var pendingSystemPickerImage: UIImage?
	@State private var pendingCroppedImage: UIImage?

	init(
		source: ImageCaptureSource, previewImages: [UIImage]? = nil, cropShape: CropShape,
		onComplete: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void
	) {
		self.cropShape = cropShape
		self.previewImages = previewImages
		self.onComplete = onComplete
		self.onCancel = onCancel
		let initialStage: ImageCaptureStage = source == .camera ? .camera : .photoPreview
		_coordinator = State(initialValue: ImageCaptureCoordinator(stage: initialStage))
	}

	var body: some View {
		Group {
			switch coordinator.stage {
			case .sourceMenu:
				ImageSourceSelectionView(onCamera: openCamera, onPhotos: coordinator.chosePhotos, onCancel: onCancel)
			case .camera:
				CameraSourceView(cameraModel: cameraModel, onCapture: { select($0, from: .camera) }, onBack: coordinator.wentBack)
			case .photoPreview, .systemPhotoPicker:
				LightweightPhotoPreviewView(
					previewImages: previewImages, onPicked: { select($0, from: .photoPreview) },
					onBack: coordinator.wentBack, onAllPhotos: coordinator.choseAllPhotos)
			}
		}
		.presentationDetents(coordinator.stage == .camera ? [.large] : [.medium, .large])
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .active else { return }
			cameraModel.refresh()
		}
		.fullScreenCover(isPresented: systemPickerPresented, onDismiss: finishSystemPickerDismissal) {
			SystemPhotoPicker(
				onPicked: {
					pendingSystemPickerImage = $0
					coordinator.pickerFinishedWithoutImage()
				}, onCancel: coordinator.pickerFinishedWithoutImage)
		}
		.fullScreenCover(item: $selectedImage, onDismiss: finishCropDismissal) { item in
			CropStep(
				image: item.image, shape: cropShape,
				onComplete: {
					pendingCroppedImage = $0.downsized(maxPixelSide: cropShape.maxPixelSize)
					selectedImage = nil
					coordinator.completedCrop()
				},
				onCancel: {
					selectedImage = nil
					coordinator.cancelledCrop()
				})
		}
	}

	private func finishCropDismissal() {
		guard let image = pendingCroppedImage else { return }
		pendingCroppedImage = nil
		onComplete(image)
	}

	private func openCamera() {
		Task {
			await cameraModel.requestIfNeeded()
			coordinator.choseCamera()
		}
	}

	private func select(_ image: UIImage, from origin: ImageCaptureSelectionOrigin) {
		coordinator.selectedImage(from: origin)
		selectedImage = IdentifiableImage(image: image)
	}

	private var systemPickerPresented: Binding<Bool> {
		Binding(get: { coordinator.stage == .systemPhotoPicker }, set: { if !$0 { coordinator.pickerFinishedWithoutImage() } })
	}

	private func finishSystemPickerDismissal() {
		guard let image = pendingSystemPickerImage else { return }
		pendingSystemPickerImage = nil
		select(image, from: .photoPreview)
	}
}

#Preview("Camera") {
	ImageCaptureFlowView(source: .camera, cropShape: .rectangle, onComplete: { _ in }, onCancel: {})
}
