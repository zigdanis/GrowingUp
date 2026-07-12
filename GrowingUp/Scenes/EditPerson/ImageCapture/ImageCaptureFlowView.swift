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
                ImageSourceMenuView(
                    onCamera: openCamera,
                    onPhotos: coordinator.chosePhotos,
                    onCancel: onCancel
                )
            case .camera:
                CameraSourceView(
                    cameraModel: cameraModel,
                    onCapture: { select($0, from: .camera) },
                    onBack: onCancel
                )
            case .photoPreview:
                LightweightPhotoPreviewView(
                    onPicked: { select($0, from: .photoPreview) },
                    onBack: onCancel,
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

private struct ImageSourceMenuView: View {
    private let cornerRadius: CGFloat = 32

    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 8) {
                SourceMenuRow(title: "Camera", systemImage: "camera", action: onCamera)
                SourceMenuRow(title: "Photos", systemImage: "photo", action: onPhotos)
            }
            .padding(12)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
            .padding(.leading, 16)
            .padding(.trailing, 48)
            .padding(.bottom, 16)
        }
    }
}

private struct SourceMenuRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.medium))
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.08), in: Circle())
                Text(title)
                    .font(.title2)
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LightweightPhotoPreviewView: View {
    let onPicked: (UIImage) -> Void
    let onBack: () -> Void
    let onAllPhotos: () -> Void

    @State private var photoModel = PhotoGridViewModel()
    @State private var selectedAsset: PhotoAsset?

    var body: some View {
        NavigationStack {
            PhotoGridView(viewModel: photoModel, selectedAsset: $selectedAsset)
                .background(Color(.secondarySystemBackground))
                .ignoresSafeArea(.container, edges: .bottom)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel(Text("Back"))

                        Spacer()

                        if selectedAsset == nil {
                            Button("All Photos", action: onAllPhotos)
                        } else {
                            Button("Select photo", action: confirmSelection)
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                        }
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .bottomBar)
        }
    }

    private func confirmSelection() {
        guard let selectedAsset else { return }
        photoModel.select(selectedAsset, completion: onPicked)
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
