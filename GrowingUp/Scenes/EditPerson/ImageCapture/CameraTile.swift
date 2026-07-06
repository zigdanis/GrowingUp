//
//  CameraTile.swift
//  GrowingUp
//
//  The first cell of the photo grid: a single camera entry surface showing a
//  glyph. Tapping it requests access when undetermined, opens the inline camera
//  card once authorized, or surfaces the explainer when denied/restricted.
//
//  The live preview deliberately lives only in the camera card, never here: two
//  AVCaptureVideoPreviewLayers sharing one session contend and one renders black.
//

import SwiftUI
import AVFoundation

struct CameraTile: View {
    let authState: AVAuthorizationStatus
    let side: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "camera.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
            .frame(width: side, height: side)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Camera"))
    }
}
