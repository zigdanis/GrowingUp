//
//  CameraTile.swift
//  GrowingUp
//
//  The first cell of the photo grid: a single camera entry surface. Shows a
//  glyph until camera access is granted, then a live AVCaptureVideoPreviewLayer.
//  Tapping it requests access when undetermined, or opens the full camera card
//  once authorized; denied/restricted taps surface the explainer.
//

import SwiftUI

struct CameraTile: View {
    let authState: CameraAuthState
    let controller: CameraSessionController
    let side: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color(.secondarySystemBackground)
                if authState.isAuthorized {
                    // Only render the live layer once the session is actually
                    // running, so an authorized tile never flashes black behind
                    // the glyph before frames arrive.
                    if controller.isRunning {
                        CameraPreview(session: controller.session, isMirrored: controller.isFront)
                    }
                    glyph(filled: true)
                } else {
                    glyph(filled: false)
                }
            }
            .frame(width: side, height: side)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Camera"))
        .task(id: authState) {
            // Re-start the session whenever the tile (re)appears authorized —
            // e.g. returning to the grid after the camera card stopped it — so
            // the live tile survives more than the first open.
            if authState.isAuthorized {
                controller.start()
            }
        }
    }

    private func glyph(filled: Bool) -> some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(filled ? Color.white : Color.secondary)
            .shadow(color: filled ? .black.opacity(0.4) : .clear, radius: 3)
    }
}
