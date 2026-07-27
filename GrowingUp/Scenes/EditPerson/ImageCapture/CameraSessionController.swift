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
		case .off: return .auto
		case .auto: return .on
		case .on: return .off
		}
	}

	var systemImage: String {
		switch self {
		case .off: return "bolt.slash.fill"
		case .auto: return "bolt.badge.a.fill"
		case .on: return "bolt.fill"
		}
	}

	fileprivate var avFlashMode: AVCaptureDevice.FlashMode {
		switch self {
		case .off: return .off
		case .auto: return .auto
		case .on: return .on
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
