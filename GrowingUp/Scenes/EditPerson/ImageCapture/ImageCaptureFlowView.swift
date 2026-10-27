import SwiftUI

struct ImageCaptureFlowView: View {
	let cropShape: CropShape
	let previewImages: [UIImage]?
	/// Gets the picked photo whole, with the region framed for the slot and the picture rendered from it.
	let onComplete: (FramedPhoto) -> Void
	let onCancel: () -> Void
	@Environment(\.scenePhase)
	private var scenePhase
	@State private var coordinator: ImageCaptureCoordinator
	@State private var cameraModel = CameraSourceModel()

	init(
		source: ImageCaptureSource, previewImages: [UIImage]? = nil, cropShape: CropShape,
		onComplete: @escaping (FramedPhoto) -> Void, onCancel: @escaping () -> Void
	) {
		self.cropShape = cropShape
		self.previewImages = previewImages
		self.onComplete = onComplete
		self.onCancel = onCancel
		let initialStage: ImageCaptureStage = source == .camera ? .camera : .photoPreview
		_coordinator = State(initialValue: ImageCaptureCoordinator(stage: initialStage))
	}

	var body: some View {
		@Bindable var coordinator = self.coordinator
		Group {
			switch coordinator.stage {
			case .camera:
				CameraSourceView(
					cameraModel: cameraModel, onCapture: { coordinator.selectedImage($0, from: .camera) }, onBack: goBack)
			case .photoPreview, .systemPhotoPicker:
				LightweightPhotoPreviewView(
					previewImages: previewImages, onPicked: { coordinator.selectedImage($0, from: .photoPreview) },
					onBack: goBack, onAllPhotos: coordinator.choseAllPhotos)
			}
		}
		.presentationDetents(coordinator.stage == .camera ? [.large] : [.medium, .large])
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .active else { return }
			cameraModel.refresh()
		}
		.fullScreenCover(isPresented: $coordinator.isSystemPickerPresented, onDismiss: coordinator.pickerDismissed) {
			SystemPhotoPicker(
				onPicked: { coordinator.pickerFinished(with: $0) },
				onCancel: { coordinator.pickerFinished(with: nil) })
		}
		.fullScreenCover(
			item: $coordinator.imageToCrop,
			onDismiss: { if let framed = coordinator.cropDismissed() { onComplete(framed) } },
			content: { item in
				CropStep(
					image: item.image, shape: cropShape, onComplete: { coordinator.completedCrop(with: $0) },
					onCancel: coordinator.cancelledCrop)
			})
	}

	/// Back from the camera or the photo preview closes the whole flow, back to the editor underneath.
	private func goBack() {
		if coordinator.wentBack() { onCancel() }
	}
}

#Preview("Camera") {
	ImageCaptureFlowView(source: .camera, cropShape: .rectangle, onComplete: { _ in }, onCancel: {})
}
