//
//  CameraSessionController.swift
//  GrowingUp
//
//  Owns the AVFoundation capture session for the inline camera card: device
//  discovery, the live preview layer, front/back flip, flash mode, and photo
//  capture. Front-camera stills are un-mirrored so the saved image matches the
//  scene rather than the selfie preview.
//

import AVFoundation
import UIKit

/// Flash mode exposed to the camera card. Mirrors AVCaptureDevice.FlashMode but
/// keeps the UI decoupled from AVFoundation and cyclable for the toggle button.
enum CameraFlashMode: CaseIterable {
    case off
    case auto
    // swiftlint:disable:next identifier_name
    case on

    var next: CameraFlashMode {
        switch self {
        case .off:  return .auto
        case .auto: return .on
        case .on:   return .off
        }
    }

    var systemImage: String {
        switch self {
        case .off:  return "bolt.slash.fill"
        case .auto: return "bolt.badge.a.fill"
        case .on:   return "bolt.fill"
        }
    }

    fileprivate var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off:  return .off
        case .auto: return .auto
        case .on:   return .on
        }
    }
}

@MainActor
@Observable
final class CameraSessionController: NSObject {

    /// The live preview session, handed to the preview layer. Configured and
    /// driven on a private serial queue; mutated only through this controller.
    @ObservationIgnored let session = AVCaptureSession()

    private(set) var flashMode: CameraFlashMode = .off
    /// True once flip is available (a usable front camera was discovered).
    private(set) var canFlip = false
    private(set) var isFront = false
    /// True while a still capture is in flight, so the shutter can be disabled.
    private(set) var isCapturing = false

    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "growingup.camera.session")
    @ObservationIgnored private let photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored private var videoInput: AVCaptureDeviceInput?
    @ObservationIgnored private var configured = false
    /// Retained until its delegate callback fires, then released.
    @ObservationIgnored private var captureContinuation: ((UIImage?) -> Void)?

    // MARK: - Lifecycle

    /// Builds the session (back camera by default) and starts running. Safe to
    /// call repeatedly; configuration happens once.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = camera(for: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
        session.commitConfiguration()

        let frontAvailable = camera(for: .front) != nil
        let backIsActive = videoInput?.device.position == .back
        Task { @MainActor in
            self.canFlip = frontAvailable
            self.isFront = !backIsActive
        }
    }

    // MARK: - Controls

    /// Swaps the active camera input between back and front.
    func flip() {
        sessionQueue.async { [weak self] in
            guard let self, let current = self.videoInput else { return }
            let newPosition: AVCaptureDevice.Position = current.device.position == .back ? .front : .back
            guard let device = self.camera(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }
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
            let nowFront = self.videoInput?.device.position == .front
            Task { @MainActor in self.isFront = nowFront }
        }
    }

    func cycleFlash() {
        flashMode = flashMode.next
    }

    // MARK: - Capture

    /// Captures a still. Completion fires on the main actor with the oriented,
    /// un-mirrored image, or nil on failure.
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true
        captureContinuation = completion
        let flash = flashMode.avFlashMode
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(flash) {
                settings.flashMode = flash
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func finishCapture(with image: UIImage?) {
        let completion = captureContinuation
        captureContinuation = nil
        isCapturing = false
        completion?(image)
    }

    // MARK: - Device discovery

    private func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        // Build the still off the main actor, then hop back to deliver it.
        let image: UIImage?
        if error == nil,
           let data = photo.fileDataRepresentation(),
           let captured = UIImage(data: data) {
            image = captured.unmirroredIfNeeded()
        } else {
            image = nil
        }
        Task { @MainActor in
            self.finishCapture(with: image)
        }
    }
}

private extension UIImage {
    /// AVFoundation already delivers un-mirrored pixel data for the front
    /// camera (unlike the live preview, which is mirrored for the selfie feel),
    /// so the saved still matches the real scene. Normalizing orientation to
    /// `.up` bakes any EXIF rotation into the pixels so downstream crop/encode
    /// steps never re-mirror or rotate it.
    func unmirroredIfNeeded() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
