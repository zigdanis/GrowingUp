import PhotosUI
import SwiftUI

enum ImageCaptureSource: Equatable {
	case camera
	case photos
}

enum ImageCaptureStage: Equatable {
	case sourceMenu
	case camera
	case photoPreview
	case systemPhotoPicker
}

enum ImageCaptureSelectionOrigin: Equatable {
	case camera
	case photoPreview
}

@MainActor
@Observable
final class ImageCaptureCoordinator {
	private(set) var stage: ImageCaptureStage
	private(set) var selectionOrigin: ImageCaptureSelectionOrigin?

	init(stage: ImageCaptureStage = .sourceMenu) {
		self.stage = stage
	}

	func choseCamera() { stage = .camera }
	func chosePhotos() { stage = .photoPreview }
	func choseAllPhotos() { stage = .systemPhotoPicker }

	func wentBack() {
		switch stage {
		case .camera, .photoPreview:
			stage = .sourceMenu
		case .systemPhotoPicker:
			stage = .photoPreview
		case .sourceMenu:
			break
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

struct ImageCaptureFlowView: View {
	let cropShape: CropShape
	let onComplete: (UIImage) -> Void
	let onCancel: () -> Void

	@Environment(\.scenePhase)
	private var scenePhase
	@State private var coordinator: ImageCaptureCoordinator
	@State private var cameraModel = CameraSourceModel()
	@State private var selectedImage: IdentifiableImage?
	@State private var pendingSystemPickerImage: UIImage?

	init(
		source: ImageCaptureSource,
		cropShape: CropShape,
		onComplete: @escaping (UIImage) -> Void,
		onCancel: @escaping () -> Void
	) {
		self.cropShape = cropShape
		self.onComplete = onComplete
		self.onCancel = onCancel
		let initialStage: ImageCaptureStage = source == .camera ? .camera : .photoPreview
		_coordinator = State(initialValue: ImageCaptureCoordinator(stage: initialStage))
	}

	var body: some View {
		Group {
			switch coordinator.stage {
			case .sourceMenu:
				ImageSourceSelectionView(
					onCamera: openCamera,
					onPhotos: coordinator.chosePhotos,
					onCancel: onCancel
				)
			case .camera:
				CameraSourceView(
					cameraModel: cameraModel,
					onCapture: { select($0, from: .camera) },
					onBack: coordinator.wentBack
				)
			case .photoPreview:
				LightweightPhotoPreviewView(
					onPicked: { select($0, from: .photoPreview) },
					onBack: coordinator.wentBack,
					onAllPhotos: coordinator.choseAllPhotos
				)
			case .systemPhotoPicker:
				LightweightPhotoPreviewView(
					onPicked: { select($0, from: .photoPreview) },
					onBack: coordinator.wentBack,
					onAllPhotos: coordinator.choseAllPhotos
				)
			}
		}
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .active else { return }
			cameraModel.refresh()
		}
		.fullScreenCover(isPresented: systemPickerPresented, onDismiss: finishSystemPickerDismissal) {
			SystemPhotoPicker(
				onPicked: { image in
					pendingSystemPickerImage = image
					coordinator.pickerFinishedWithoutImage()
				},
				onCancel: coordinator.pickerFinishedWithoutImage
			)
		}
		.fullScreenCover(item: $selectedImage) { item in
			CropStep(
				image: item.image,
				shape: cropShape,
				onComplete: { cropped in
					selectedImage = nil
					coordinator.completedCrop()
					onComplete(cropped.downsized(maxPixelSide: cropShape.maxPixelSize))
				},
				onCancel: {
					selectedImage = nil
					coordinator.cancelledCrop()
				}
			)
		}
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
		Binding(
			get: { coordinator.stage == .systemPhotoPicker },
			set: { isPresented in
				if !isPresented { coordinator.pickerFinishedWithoutImage() }
			}
		)
	}

	private func finishSystemPickerDismissal() {
		guard let image = pendingSystemPickerImage else { return }
		pendingSystemPickerImage = nil
		select(image, from: .photoPreview)
	}
}

private struct ImageSourceSelectionView: View {
	let onCamera: () -> Void
	let onPhotos: () -> Void
	let onCancel: () -> Void

	var body: some View {
		VStack(spacing: 16) {
			Spacer()
			Button("Camera", systemImage: "camera", action: onCamera)
			Button("Photos", systemImage: "photo", action: onPhotos)
			Spacer()
			Button("Cancel", role: .cancel, action: onCancel)
		}
		.buttonStyle(.bordered)
		.controlSize(.large)
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.secondarySystemBackground))
	}
}

private struct LightweightPhotoPreviewView: View {
	let onPicked: (UIImage) -> Void
	let onBack: () -> Void
	let onAllPhotos: () -> Void

	@State private var photoModel: PhotoGridViewModel

	init(
		onPicked: @escaping (UIImage) -> Void,
		onBack: @escaping () -> Void,
		onAllPhotos: @escaping () -> Void
	) {
		_photoModel = State(initialValue: PhotoGridViewModel())
		self.onPicked = onPicked
		self.onBack = onBack
		self.onAllPhotos = onAllPhotos
	}

	init(
		photoModel: PhotoGridViewModel,
		onPicked: @escaping (UIImage) -> Void,
		onBack: @escaping () -> Void,
		onAllPhotos: @escaping () -> Void
	) {
		_photoModel = State(initialValue: photoModel)
		self.onPicked = onPicked
		self.onBack = onBack
		self.onAllPhotos = onAllPhotos
	}

	var body: some View {
		NavigationStack {
			PhotoGridView(viewModel: photoModel, onPicked: onPicked)
				.background(Color(.secondarySystemBackground))
				.safeAreaInset(edge: .bottom) {
					PhotoPreviewControls(onBack: onBack, onAllPhotos: onAllPhotos)
				}
				.toolbar(.hidden, for: .navigationBar)
		}
	}
}

private struct PhotoPreviewControls: View {
	let onBack: () -> Void
	let onAllPhotos: () -> Void

	var body: some View {
		if #available(iOS 26.0, *) {
			GlassEffectContainer {
				HStack {
					Button(action: onBack) {
						Image(systemName: "chevron.left")
							.foregroundStyle(.white)
							.frame(width: 44, height: 44)
					}
					.buttonStyle(.plain)
					.glassEffect()
					.accessibilityLabel(Text("Back"))

					Spacer()

					Button(action: onAllPhotos) {
						Text("All Photos")
							.font(.headline)
							.foregroundStyle(.white)
							.padding(.horizontal, 20)
							.frame(height: 44)
					}
					.buttonStyle(.plain)
					.glassEffect()
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
			}
		} else {
			controls
				.buttonStyle(.bordered)
				.tint(.black)
		}
	}

	private var controls: some View {
		HStack {
			Button(action: onBack) {
				Image(systemName: "chevron.left")
					.foregroundStyle(.white)
			}
			.accessibilityLabel(Text("Back"))

			Spacer()

			Button(action: onAllPhotos) {
				Text("All Photos")
					.font(.headline)
					.foregroundStyle(.white)
			}
		}
		.controlSize(.large)
		.padding(.horizontal, 16)
		.padding(.vertical, 8)
	}
}

private struct CameraSourceView: View {
	let cameraModel: CameraSourceModel
	let onCapture: (UIImage) -> Void
	let onBack: () -> Void

	var body: some View {
		if cameraModel.canShowLiveCamera {
			CameraCardView(
				controller: cameraModel.controller,
				onCapture: onCapture,
				onClose: onBack
			)
		} else if let config = cameraModel.explainerConfig {
			ZStack(alignment: .topLeading) {
				PermissionExplainerView(
					config: config,
					primaryAction: cameraModel.authState == .notDetermined ? requestAccess : nil
				)
				Button(action: onBack) {
					Image(systemName: "chevron.left")
						.font(.title3.weight(.semibold))
						.padding(16)
				}
				.accessibilityLabel(Text("Back"))
			}
		}
	}

	private func requestAccess() {
		Task { await cameraModel.requestIfNeeded() }
	}
}

private struct SystemPhotoPicker: UIViewControllerRepresentable {
	let onPicked: (UIImage) -> Void
	let onCancel: () -> Void

	func makeCoordinator() -> Coordinator {
		Coordinator(onPicked: onPicked, onCancel: onCancel)
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

	final class Coordinator: NSObject, PHPickerViewControllerDelegate {
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
					if let image = object as? UIImage {
						onPicked(image)
					} else {
						onCancel()
					}
				}
			}
		}
	}
}

private struct IdentifiableImage: Identifiable {
	let id = UUID()
	let image: UIImage
}

#Preview("Camera") {
	ImageCaptureFlowView(
		source: .camera,
		cropShape: .rectangle,
		onComplete: { _ in },
		onCancel: {}
	)
}

#Preview("Photos") {
	LightweightPhotoPreviewView(
		photoModel: PhotoGridViewModel(previewImages: PreviewPhotos.images),
		onPicked: { _ in },
		onBack: {},
		onAllPhotos: {}
	)
}

private enum PreviewPhotos {
	static let images = [
		image(symbol: "figure.2.and.child.holdinghands", colors: [.systemOrange, .systemPink]),
		image(symbol: "mountain.2.fill", colors: [.systemTeal, .systemBlue]),
		image(symbol: "sun.max.fill", colors: [.systemYellow, .systemOrange]),
		image(symbol: "pawprint.fill", colors: [.systemIndigo, .systemPurple]),
		image(symbol: "balloon.2.fill", colors: [.systemPink, .systemRed]),
		image(symbol: "tree.fill", colors: [.systemGreen, .systemTeal]),
		image(symbol: "beach.umbrella.fill", colors: [.systemCyan, .systemBlue]),
		image(symbol: "birthday.cake.fill", colors: [.systemPink, .systemOrange]),
		image(symbol: "bicycle", colors: [.systemGreen, .systemBlue]),
		image(symbol: "camera.fill", colors: [.systemPurple, .systemPink]),
		image(symbol: "car.fill", colors: [.systemRed, .systemOrange]),
		image(symbol: "cloud.sun.fill", colors: [.systemBlue, .systemYellow]),
		image(symbol: "figure.hiking", colors: [.systemBrown, .systemGreen]),
		image(symbol: "fish.fill", colors: [.systemTeal, .systemIndigo]),
		image(symbol: "gift.fill", colors: [.systemRed, .systemPurple]),
		image(symbol: "house.fill", colors: [.systemOrange, .systemBrown]),
		image(symbol: "moon.stars.fill", colors: [.systemIndigo, .black]),
		image(symbol: "sailboat.fill", colors: [.systemCyan, .systemTeal])
	]

	private static func image(symbol: String, colors: [UIColor]) -> UIImage {
		let size = CGSize(width: 360, height: 360)
		return UIGraphicsImageRenderer(size: size).image { context in
			let gradient = CGGradient(
				colorsSpace: CGColorSpaceCreateDeviceRGB(),
				colors: colors.map(\.cgColor) as CFArray,
				locations: [0, 1]
			)!
			context.cgContext.drawLinearGradient(
				gradient,
				start: .zero,
				end: CGPoint(x: size.width, y: size.height),
				options: []
			)
			let configuration = UIImage.SymbolConfiguration(pointSize: 110, weight: .medium)
			let icon = UIImage(systemName: symbol, withConfiguration: configuration)!
			icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(
				at: CGPoint(x: (size.width - icon.size.width) / 2, y: (size.height - icon.size.height) / 2)
			)
		}
	}
}
