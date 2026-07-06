//
//  ImageCaptureFlowView.swift
//  GrowingUp
//
//  Root of the image-pick flow hosted into the UIKit EditPerson scene.
//  Sources: a custom photo-library grid and an inline in-app camera card,
//  surfaced as the grid's first tile. Either source yields one image that runs
//  through the shared CropStep. The seam contract (`onComplete(UIImage)` /
//  `onCancel`) is unchanged, so the host UIKit code is untouched.
//

import SwiftUI

struct ImageCaptureFlowView: View {
    let cropShape: CropShape
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @Environment(\.scenePhase)
    private var scenePhase

    @State private var cameraModel = CameraSourceModel()
    @State private var showCamera = false
    @State private var libraryImage: IdentifiableImage?

    var body: some View {
        NavigationStack {
            PhotoGridView(
                cameraModel: cameraModel,
                onCameraTapped: openCamera,
                onPicked: { image in
                    libraryImage = IdentifiableImage(image: image)
                }
            )
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            // The camera is pushed (not a full-screen cover) so it stays inside
            // the host sheet card rather than taking over the whole screen.
            .navigationDestination(isPresented: $showCamera) {
                CameraSourceView(
                    cameraModel: cameraModel,
                    cropShape: cropShape,
                    onComplete: finishCamera,
                    onClose: { showCamera = false }
                )
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            cameraModel.refresh()
        }
        .fullScreenCover(item: $libraryImage) { item in
            CropStep(
                image: item.image,
                shape: cropShape,
                onComplete: { cropped in
                    libraryImage = nil
                    finish(cropped)
                },
                onCancel: {
                    // Back to the grid to choose another photo.
                    libraryImage = nil
                }
            )
        }
    }

    private func openCamera() {
        switch cameraModel.authState {
        case .authorized:
            if cameraModel.canShowLiveCamera {
                cameraModel.controller.start()
            }
            showCamera = true
        case .notDetermined:
            Task {
                await cameraModel.requestIfNeeded()
                if cameraModel.canShowLiveCamera {
                    cameraModel.controller.start()
                }
                showCamera = true
            }
        case .denied, .restricted:
            showCamera = true
        }
    }

    private func finishCamera(_ cropped: UIImage) {
        showCamera = false
        finish(cropped)
    }

    private func finish(_ cropped: UIImage) {
        onComplete(cropped.downsized(maxPixelSide: cropShape.maxPixelSize))
    }
}

/// The camera leg of the flow: live card (or permission explainer) plus its own
/// crop step. Keeping the crop cover here means crop-cancel retakes by simply
/// dismissing back onto the still-presented card.
private struct CameraSourceView: View {
    let cameraModel: CameraSourceModel
    let cropShape: CropShape
    let onComplete: (UIImage) -> Void
    let onClose: () -> Void

    @State private var captured: IdentifiableImage?

    var body: some View {
        content
            .fullScreenCover(item: $captured) { item in
                CropStep(
                    image: item.image,
                    shape: cropShape,
                    onComplete: { cropped in
                        captured = nil
                        onComplete(cropped)
                    },
                    onCancel: {
                        // Back to the live card to retake.
                        captured = nil
                    }
                )
            }
    }

    @ViewBuilder private var content: some View {
        if cameraModel.canShowLiveCamera {
            CameraCardView(
                controller: cameraModel.controller,
                onCapture: { image in
                    captured = IdentifiableImage(image: image)
                },
                onClose: onClose
            )
        } else if let config = cameraModel.explainerConfig {
            explainer(config)
        }
    }

    private func explainer(_ config: PermissionExplainerConfig) -> some View {
        ZStack(alignment: .topLeading) {
            PermissionExplainerView(
                config: config,
                primaryAction: cameraModel.authState == .notDetermined ? requestAccess : nil
            )
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .padding(16)
            }
            .accessibilityLabel(Text("Close"))
        }
    }

    private func requestAccess() {
        Task {
            await cameraModel.requestIfNeeded()
            if cameraModel.authState.isAuthorized {
                cameraModel.controller.start()
            }
        }
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
