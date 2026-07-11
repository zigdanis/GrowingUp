import PhotosUI
import SwiftUI

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
    private(set) var stage: ImageCaptureStage = .sourceMenu
    private(set) var selectionOrigin: ImageCaptureSelectionOrigin?

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
    @State private var coordinator = ImageCaptureCoordinator()
    @State private var cameraModel = CameraSourceModel()
    @State private var selectedImage: IdentifiableImage?
    @State private var pendingSystemPickerImage: UIImage?

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

private struct ImageSourceMenuView: View {
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                SourceMenuRow(title: "Camera", systemImage: "camera.fill", action: onCamera)
                Divider().padding(.leading, 76)
                SourceMenuRow(title: "Photos", systemImage: "photo.on.rectangle", action: onPhotos)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

private struct SourceMenuRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
                Text(title)
                    .font(.title3.weight(.medium))
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LightweightPhotoPreviewView: View {
    let onPicked: (UIImage) -> Void
    let onBack: () -> Void
    let onAllPhotos: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            PhotoPreviewHeader(onBack: onBack, onAllPhotos: onAllPhotos)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            PhotoGridView(onPicked: onPicked)
        }
        .background(.background)
    }
}

private struct PhotoPreviewHeader: View {
    let onBack: () -> Void
    let onAllPhotos: () -> Void

    var body: some View {
        HStack {
            GlassControl(title: "Back", systemImage: "chevron.left", action: onBack)
            Spacer()
            GlassControl(title: "All Photos", systemImage: "photo.stack", action: onAllPhotos)
        }
    }
}

private struct GlassControl: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(height: 44)
                .padding(.horizontal, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.35), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
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
