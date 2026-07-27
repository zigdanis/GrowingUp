//
//  CameraSessionWorker.swift
//  GrowingUp
//
//  Serial-queue AVFoundation worker behind CameraSessionController.
//

import AVFoundation
import UIKit

final class CameraSessionWorker: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
  struct State: Sendable {
    let isRunning: Bool
    let canFlip: Bool
    let isFront: Bool
  }

  let session = AVCaptureSession()

  private let sessionQueue = DispatchQueue(label: "growingup.camera.session")
  private let photoOutput = AVCapturePhotoOutput()
  private var videoInput: AVCaptureDeviceInput?
  private var configured = false
  private var captureCompletion: (@Sendable (UIImage?) -> Void)?

  func start(onStateChange: @escaping @Sendable (State) -> Void) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      self.configureIfNeeded()
      if !self.session.isRunning {
        self.session.startRunning()
      }
      onStateChange(self.currentState())
    }
  }

  func stop(onRunningChange: @escaping @Sendable (Bool) -> Void) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if self.session.isRunning {
        self.session.stopRunning()
      }
      onRunningChange(false)
    }
  }

  func flip(onPositionChange: @escaping @Sendable (Bool) -> Void) {
    sessionQueue.async { [weak self] in
      guard let self, let current = self.videoInput else { return }
      let newPosition: AVCaptureDevice.Position = current.device.position == .back ? .front : .back
      guard let device = self.camera(for: newPosition),
        let newInput = try? AVCaptureDeviceInput(device: device)
      else { return }

      self.session.beginConfiguration()
      self.session.removeInput(current)
      if self.session.canAddInput(newInput) {
        self.session.addInput(newInput)
        self.videoInput = newInput
      } else if self.session.canAddInput(current) {
        // Roll back to the previous input if the swap is rejected.
        self.session.addInput(current)
      }
      self.session.commitConfiguration()
      onPositionChange(self.videoInput?.device.position == .front)
    }
  }

  func capturePhoto(
    flash: AVCaptureDevice.FlashMode,
    mirrorOutput: Bool,
    completion: @escaping @Sendable (UIImage?) -> Void
  ) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      // No active video connection (e.g. Simulator / no camera hardware):
      // calling `capturePhoto` would raise an exception, so fail gracefully.
      guard let connection = self.photoOutput.connection(with: .video),
        connection.isActive, connection.isEnabled
      else {
        completion(nil)
        return
      }

      let settings = AVCapturePhotoSettings()
      if self.photoOutput.supportedFlashModes.contains(flash) {
        settings.flashMode = flash
      }
      self.captureCompletion = { image in
        completion(mirrorOutput ? image?.horizontallyMirrored() : image)
      }
      self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    // Build the still off the main actor, then hop back to deliver it.
    let image: UIImage?
    if error == nil,
      let data = photo.fileDataRepresentation(),
      let captured = UIImage(data: data)
    {
      image = captured.normalizedOrientation()
    } else {
      image = nil
    }
    sessionQueue.async { [weak self] in
      guard let self else { return }
      let completion = self.captureCompletion
      self.captureCompletion = nil
      completion?(image)
    }
  }

  private func configureIfNeeded() {
    guard !configured else { return }
    configured = true
    session.beginConfiguration()
    session.sessionPreset = .photo
    if let device = camera(for: .back),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    {
      session.addInput(input)
      videoInput = input
    }
    if session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
      photoOutput.maxPhotoQualityPrioritization = .quality
    }
    session.commitConfiguration()
  }

  private func currentState() -> State {
    State(
      isRunning: session.isRunning,
      canFlip: camera(for: .front) != nil,
      isFront: videoInput?.device.position == .front
    )
  }

  private func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: position
    )
    return discovery.devices.first
  }
}

private extension UIImage {
  /// Normalizing orientation to `.up` bakes any EXIF rotation into the pixels
  /// so downstream crop/encode steps never rotate it.
  func normalizedOrientation() -> UIImage {
    guard imageOrientation != .up else { return self }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }

  /// Mirrors pixels horizontally so front-camera capture matches the mirrored
  /// live preview shown at shutter time.
  func horizontallyMirrored() -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
      let cgContext = context.cgContext
      cgContext.translateBy(x: size.width, y: 0)
      cgContext.scaleBy(x: -1, y: 1)
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
