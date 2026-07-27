//
//  CameraPreview.swift
//  GrowingUp
//
//  SwiftUI bridge for AVCaptureVideoPreviewLayer. A thin UIView whose backing
//  layer is the preview layer, so the live feed fills the view and resizes with
//  it. Mirrored for the front camera to give the expected selfie feel — the
//  saved still is un-mirrored separately in CameraSessionController.
//

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession
  /// When true (front camera), the preview is horizontally mirrored.
  var isMirrored: Bool = false

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.videoPreviewLayer.session = session
    view.videoPreviewLayer.videoGravity = .resizeAspectFill
    return view
  }

  func updateUIView(_ view: PreviewView, context: Context) {
    if view.videoPreviewLayer.session !== session {
      view.videoPreviewLayer.session = session
    }
    let connection = view.videoPreviewLayer.connection
    if connection?.isVideoMirroringSupported == true {
      connection?.automaticallyAdjustsVideoMirroring = false
      connection?.isVideoMirrored = isMirrored
    }
  }

  /// A UIView backed by an AVCaptureVideoPreviewLayer so layout drives the
  /// layer's frame for free.
  final class PreviewView: UIView {
    // `layerClass` is a UIKit override point, not an instance-independent
    // constant — it must stay a `class` property.
    // swiftlint:disable:next static_over_final_class
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
      // swiftlint:disable:next force_cast
      layer as! AVCaptureVideoPreviewLayer
    }
  }
}
