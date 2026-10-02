//
//  CameraSourceTests.swift
//  GrowingUpTests
//
//  Covers the pure logic of the inline camera source: auth-state mapping, the
//  flash-mode cycle, and the CameraSourceModel permission state machine driven
//  through its injectable status/request seams (no real AVFoundation prompt).
//

import AVFoundation
import UIKit
import XCTest

@testable import GrowingUp

@MainActor
final class CameraSourceTests: XCTestCase {

	func testSystemPickerStartsCropOnlyAfterDismissal() {
		let coordinator = ImageCaptureCoordinator(stage: .photoPreview)
		let image = UIImage()
		coordinator.choseAllPhotos()
		coordinator.pickerFinished(with: image)
		XCTAssertFalse(coordinator.isSystemPickerPresented)
		XCTAssertNil(coordinator.imageToCrop)

		coordinator.isSystemPickerPresented = false
		coordinator.pickerDismissed()
		XCTAssertTrue(coordinator.imageToCrop?.image === image)
		coordinator.pickerDismissed()
		XCTAssertTrue(coordinator.imageToCrop?.image === image)
	}

	func testCropResultIsHandedOffOnceAfterDismissal() {
		let coordinator = ImageCaptureCoordinator(stage: .photoPreview)
		let croppedImage = UIImage()
		coordinator.choseAllPhotos()
		coordinator.pickerFinished(with: UIImage())
		coordinator.pickerDismissed()
		coordinator.completedCrop(with: croppedImage)
		XCTAssertNil(coordinator.imageToCrop)

		coordinator.imageToCrop = nil
		coordinator.completedCrop(with: UIImage())
		XCTAssertTrue(coordinator.cropDismissed() === croppedImage)
		XCTAssertNil(coordinator.cropDismissed())
	}

	func testCancelledCropReturnsToItsSourceAndCanSelectAgain() {
		let sources: [(ImageCaptureSelectionOrigin, ImageCaptureStage)] = [(.camera, .camera), (.photoPreview, .photoPreview)]
		for (origin, stage) in sources {
			let coordinator = ImageCaptureCoordinator(stage: stage)
			let firstImage = UIImage()
			let nextImage = UIImage()
			coordinator.selectedImage(firstImage, from: origin)
			XCTAssertTrue(coordinator.imageToCrop?.image === firstImage)
			coordinator.cancelledCrop()
			coordinator.imageToCrop = nil
			XCTAssertEqual(coordinator.stage, stage)
			XCTAssertNil(coordinator.imageToCrop)
			XCTAssertNil(coordinator.cropDismissed())

			coordinator.selectedImage(nextImage, from: origin)
			XCTAssertTrue(coordinator.imageToCrop?.image === nextImage)
			coordinator.imageToCrop = nil
			XCTAssertEqual(coordinator.stage, stage)
			XCTAssertNil(coordinator.cropDismissed())
		}
	}

	func test_ImageCaptureCoordinator_routesBackFromCameraToSourceMenu() {
		let coordinator = ImageCaptureCoordinator()
		XCTAssertEqual(coordinator.stage, .sourceMenu)
		coordinator.choseCamera()
		XCTAssertEqual(coordinator.stage, .camera)
		coordinator.wentBack()
		XCTAssertEqual(coordinator.stage, .sourceMenu)
	}

	func test_ImageCaptureCoordinator_routesBackFromPhotoPreviewToSourceMenu() {
		let coordinator = ImageCaptureCoordinator()
		coordinator.chosePhotos()
		XCTAssertEqual(coordinator.stage, .photoPreview)
		coordinator.wentBack()
		XCTAssertEqual(coordinator.stage, .sourceMenu)
	}

	func test_ImageCaptureCoordinator_pickerCancelAndFailureReturnToPhotoPreview() {
		let coordinator = ImageCaptureCoordinator()
		coordinator.chosePhotos()
		coordinator.choseAllPhotos()
		XCTAssertEqual(coordinator.stage, .systemPhotoPicker)
		coordinator.pickerFinishedWithoutImage()
		XCTAssertEqual(coordinator.stage, .photoPreview)
	}

	func test_ImageCaptureCoordinator_cropCancelReturnsToCameraOrigin() {
		let coordinator = ImageCaptureCoordinator()
		coordinator.choseCamera()
		coordinator.selectedImage(from: .camera)
		XCTAssertEqual(coordinator.selectionOrigin, .camera)
		coordinator.cancelledCrop()
		XCTAssertEqual(coordinator.stage, .camera)
		XCTAssertNil(coordinator.selectionOrigin)
	}

	func test_ImageCaptureCoordinator_systemPickerCropCancelReturnsToPhotoPreview() {
		let coordinator = ImageCaptureCoordinator()
		coordinator.chosePhotos()
		coordinator.choseAllPhotos()
		coordinator.selectedImage(from: .photoPreview)
		coordinator.cancelledCrop()
		XCTAssertEqual(coordinator.stage, .photoPreview)
		XCTAssertNil(coordinator.selectionOrigin)
	}

	// MARK: - AVAuthorizationStatus

	func test_AVAuthorizationStatus_isCameraAuthorizedOnlyWhenAuthorized() {
		XCTAssertTrue(AVAuthorizationStatus.authorized.isCameraAuthorized)
		XCTAssertFalse(AVAuthorizationStatus.notDetermined.isCameraAuthorized)
		XCTAssertFalse(AVAuthorizationStatus.denied.isCameraAuthorized)
		XCTAssertFalse(AVAuthorizationStatus.restricted.isCameraAuthorized)
	}

	// MARK: - CameraFlashMode

	func test_CameraFlashMode_cyclesOffAutoOn() {
		XCTAssertEqual(CameraFlashMode.off.next, .auto)
		XCTAssertEqual(CameraFlashMode.auto.next, .on)
		XCTAssertEqual(CameraFlashMode.on.next, .off)
	}

	func test_CameraFlashMode_hasDistinctSystemImages() {
		let images = Set(CameraFlashMode.allCases.map { $0.systemImage })
		XCTAssertEqual(images.count, CameraFlashMode.allCases.count)
	}

	// MARK: - CameraSourceModel

	func test_Model_initialState_reflectsCurrentStatus() {
		let model = CameraSourceModel(
			currentStatus: { .authorized },
			requestAccess: { true },
			hasCaptureDevice: { true }
		)
		XCTAssertEqual(model.authState, .authorized)
		XCTAssertNil(model.explainerConfig)
	}

	func test_Model_requestIfNeeded_grantsAccess() async {
		var status: AVAuthorizationStatus = .notDetermined
		let model = CameraSourceModel(
			currentStatus: { status },
			requestAccess: {
				status = .authorized
				return true
			}
		)
		XCTAssertEqual(model.authState, .notDetermined)
		await model.requestIfNeeded()
		XCTAssertEqual(model.authState, .authorized)
	}

	func test_Model_requestIfNeeded_deniesAccess() async {
		var status: AVAuthorizationStatus = .notDetermined
		let model = CameraSourceModel(
			currentStatus: { status },
			requestAccess: {
				status = .denied
				return false
			}
		)
		await model.requestIfNeeded()
		XCTAssertEqual(model.authState, .denied)
	}

	func test_Model_requestIfNeeded_isNoOpWhenTerminal() async {
		var requestCount = 0
		let model = CameraSourceModel(
			currentStatus: { .denied },
			requestAccess: {
				requestCount += 1
				return false
			}
		)
		await model.requestIfNeeded()
		XCTAssertEqual(requestCount, 0, "Must not re-prompt once a terminal state is reached")
	}

	func test_Model_explainerConfig_perState() {
		XCTAssertNil(CameraSourceModel(currentStatus: { .authorized }, hasCaptureDevice: { true }).explainerConfig)
		XCTAssertNotNil(CameraSourceModel(currentStatus: { .authorized }, hasCaptureDevice: { false }).explainerConfig)
		XCTAssertNotNil(CameraSourceModel(currentStatus: { .notDetermined }).explainerConfig)
		XCTAssertNotNil(CameraSourceModel(currentStatus: { .denied }).explainerConfig)
		XCTAssertNotNil(CameraSourceModel(currentStatus: { .restricted }).explainerConfig)
	}

	func test_Model_refresh_rereadsStatus() {
		var status: AVAuthorizationStatus = .notDetermined
		let model = CameraSourceModel(currentStatus: { status })
		status = .authorized
		model.refresh()
		XCTAssertEqual(model.authState, .authorized)
	}
}
