//
//  CameraSessionController.swift
//  GrowingUp
//
//  Owns the AVFoundation capture session for the inline camera card: device
//  discovery, the live preview layer, front/back flip, flash mode, and photo
//  capture. Front-camera stills are mirrored so the crop step matches the
//  selfie preview the user saw when pressing the shutter.
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
final class CameraSessionController {

    /// The live preview session, handed to the preview layer.
    var session: AVCaptureSession { worker.session }

    private(set) var flashMode: CameraFlashMode = .off
    /// True once flip is available (a usable front camera was discovered).
    private(set) var canFlip = false
    private(set) var isFront = false
    /// True while a still capture is in flight, so the shutter can be disabled.
    private(set) var isCapturing = false
    /// True while the session is running, so the tile only renders the live
    /// preview once frames are actually flowing (no black flash behind the glyph).
    private(set) var isRunning = false

    @ObservationIgnored private let worker = CameraSessionWorker()
    /// Retained until its delegate callback fires, then released.
    @ObservationIgnored private var captureContinuation: ((UIImage?) -> Void)?

    /// Whether this device exposes any usable capture camera. Cheap synchronous
    /// discovery — `false` on the Simulator, which has no camera hardware. Use to
    /// gate the live card so we never present a dead preview with a live shutter.
    nonisolated static var hasCaptureDevice: Bool {
        !AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.isEmpty
    }

    // MARK: - Lifecycle

    /// Builds the session (back camera by default) and starts running. Safe to
    /// call repeatedly; configuration happens once.
    func start() {
        worker.start { [weak self] state in
            Task { @MainActor in
                self?.apply(state)
            }
        }
    }

    func stop() {
        worker.stop { [weak self] running in
            Task { @MainActor in
                self?.isRunning = running
            }
        }
    }

    // MARK: - Controls

    /// Swaps the active camera input between back and front.
    func flip() {
        worker.flip { [weak self] isFront in
            Task { @MainActor in
                self?.isFront = isFront
            }
        }
    }

    func cycleFlash() {
        flashMode = flashMode.next
    }

    // MARK: - Capture

    /// Captures a still. Completion fires on the main actor with an image that
    /// matches the visible preview orientation, or nil on failure.
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true
        captureContinuation = completion
        let flash = flashMode.avFlashMode
        let isFront = isFront
        worker.capturePhoto(flash: flash, mirrorOutput: isFront) { [weak self] image in
            Task { @MainActor in
                self?.finishCapture(with: image)
            }
        }
    }

    private func finishCapture(with image: UIImage?) {
        let completion = captureContinuation
        captureContinuation = nil
        isCapturing = false
        completion?(image)
    }

    private func apply(_ state: CameraSessionWorker.State) {
        canFlip = state.canFlip
        isFront = state.isFront
        isRunning = state.isRunning
    }
}

private final class CameraSessionWorker: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
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
            onPositionChange(self.videoInput?.device.position == .front)
        }
    }

    func capturePhoto(flash: AVCaptureDevice.FlashMode,
                      mirrorOutput: Bool,
                      completion: @escaping @Sendable (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // No active video connection (e.g. Simulator / no camera hardware):
            // calling `capturePhoto` would raise an exception, so fail gracefully.
            guard let connection = self.photoOutput.connection(with: .video),
                  connection.isActive, connection.isEnabled else {
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

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        // Build the still off the main actor, then hop back to deliver it.
        let image: UIImage?
        if error == nil,
           let data = photo.fileDataRepresentation(),
           let captured = UIImage(data: data) {
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
           session.canAddInput(input) {
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
