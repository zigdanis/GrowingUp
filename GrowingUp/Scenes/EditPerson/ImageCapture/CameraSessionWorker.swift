//
//  CameraSessionWorker.swift
//  GrowingUp
//
//  Serial-queue AVFoundation worker behind CameraSessionController. A rotation
//  coordinator keeps the preview upright in its window and photos level with the
//  horizon, whichever way the device is held.
//

import AVFoundation

final class CameraSessionWorker: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
	let session = AVCaptureSession()

	private let sessionQueue = DispatchQueue(label: "growingup.camera.session")
	private let photoOutput = AVCapturePhotoOutput()
	private var videoInput: AVCaptureDeviceInput?
	private var configured = false
	private var captureCompletion: (@Sendable (Data?) -> Void)?
	private var previewLayer: AVCaptureVideoPreviewLayer?
	private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
	private var previewRotation: NSKeyValueObservation?

	func start(onStateChange: @escaping @Sendable (CameraSessionState) -> Void) {
		sessionQueue.async { [weak self] in
			guard let self else { return }
			self.configureIfNeeded()
			self.coordinateRotation()
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
			self.coordinateRotation()
			onPositionChange(self.videoInput?.device.position == .front)
		}
	}

	/// Takes the live preview's layer, whose window decides which way is up for the preview.
	func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
		sessionQueue.async { [weak self] in
			guard let self else { return }
			self.previewLayer = layer
			self.coordinateRotation()
		}
	}

	/// Captures a still and hands over its encoded data, or nil on failure.
	func capturePhoto(flash: AVCaptureDevice.FlashMode, completion: @escaping @Sendable (Data?) -> Void) {
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

			// The photo comes out level with the horizon, as the device is held now.
			if let angle = self.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
				connection.isVideoRotationAngleSupported(angle)
			{
				connection.videoRotationAngle = angle
			}
			let settings = AVCapturePhotoSettings()
			if self.photoOutput.supportedFlashModes.contains(flash) {
				settings.flashMode = flash
			}
			self.captureCompletion = completion
			self.photoOutput.capturePhoto(with: settings, delegate: self)
		}
	}

	func photoOutput(
		_ output: AVCapturePhotoOutput,
		didFinishProcessingPhoto photo: AVCapturePhoto,
		error: Error?
	) {
		// Only the encoded photo; the controller decodes it to the working image.
		let data = error == nil ? photo.fileDataRepresentation() : nil
		sessionQueue.async { [weak self] in
			guard let self else { return }
			let completion = self.captureCompletion
			self.captureCompletion = nil
			completion?(data)
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

	/// Follows the current camera's rotation for its preview layer: the preview turns with the window, and a capture
	/// reads the coordinator's angle for the photo.
	private func coordinateRotation() {
		guard let device = videoInput?.device, let previewLayer else { return }
		let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
		rotationCoordinator = coordinator
		let rotate = { [weak previewLayer] (angle: CGFloat) in
			DispatchQueue.main.async {
				guard let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(angle) else { return }
				connection.videoRotationAngle = angle
			}
		}
		previewRotation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { coordinator, _ in
			rotate(coordinator.videoRotationAngleForHorizonLevelPreview)
		}
	}

	private func currentState() -> CameraSessionState {
		CameraSessionState(
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
