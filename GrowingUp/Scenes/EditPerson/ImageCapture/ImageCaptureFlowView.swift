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
		@Bindable var coordinator = self.coordinator
		Group {
			switch coordinator.stage {
			case .sourceMenu:
				ImageSourceSelectionView(onCamera: openCamera, onPhotos: coordinator.chosePhotos, onCancel: onCancel)
			case .camera:
				CameraSourceView(
					cameraModel: cameraModel, onCapture: { coordinator.selectedImage($0, from: .camera) }, onBack: coordinator.wentBack)
			case .photoPreview, .systemPhotoPicker:
				LightweightPhotoPreviewView(
					previewImages: previewImages, onPicked: { coordinator.selectedImage($0, from: .photoPreview) },
					onBack: coordinator.wentBack, onAllPhotos: coordinator.choseAllPhotos)
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
			onDismiss: { if let image = coordinator.cropDismissed() { onComplete(image) } },
			content: { item in
				CropStep(
					image: item.image, shape: cropShape,
					onComplete: {
						coordinator.completedCrop(with: $0.downsized(maxPixelSide: cropShape.maxPixelSize))
					},
					onCancel: coordinator.cancelledCrop)
			})
	}

	private func openCamera() {
		Task {
			await cameraModel.requestIfNeeded()
			coordinator.choseCamera()
		}
	}
}

#Preview("Camera") {
	ImageCaptureFlowView(source: .camera, cropShape: .rectangle, onComplete: { _ in }, onCancel: {})
}
