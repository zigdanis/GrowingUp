//
//  CameraSourceModel.swift
//  GrowingUp
//
//  Owns the camera source's authorization state and the live session
//  controller, so the grid's camera tile and the inline camera card share one
//  source of truth. Mirrors the photo grid's auth handling on the camera side.
//

import AVFoundation
import SwiftUI

@MainActor
@Observable
final class CameraSourceModel {

    private(set) var authState: CameraAuthState
    let controller = CameraSessionController()

    /// Injectable so tests can drive the state machine without the real
    /// AVFoundation prompt. Defaults to the system camera authorization APIs.
    @ObservationIgnored private let currentStatus: () -> AVAuthorizationStatus
    @ObservationIgnored private let requestAccess: () async -> Bool
    /// Injectable so tests can simulate camera hardware presence/absence (the
    /// Simulator never has a capture device). Defaults to the real check.
    @ObservationIgnored private let hasCaptureDevice: () -> Bool

    init(
        currentStatus: @escaping () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        requestAccess: @escaping () async -> Bool = {
            await AVCaptureDevice.requestAccess(for: .video)
        },
        hasCaptureDevice: @escaping () -> Bool = { CameraSessionController.hasCaptureDevice }
    ) {
        self.currentStatus = currentStatus
        self.requestAccess = requestAccess
        self.hasCaptureDevice = hasCaptureDevice
        self.authState = CameraAuthState(currentStatus())
    }

    /// Re-reads the current status, e.g. after returning from Settings.
    func refresh() {
        authState = CameraAuthState(currentStatus())
    }

    /// Triggers the system prompt when undetermined and applies the result.
    /// No-op once a terminal state (authorized/denied/restricted) is reached.
    func requestIfNeeded() async {
        guard authState == .notDetermined else { return }
        let granted = await requestAccess()
        authState = CameraAuthState(currentStatus())
        // Fall back to a direct mapping if the status hasn't settled yet.
        if authState == .notDetermined {
            authState = granted ? .authorized : .denied
        }
    }

    /// Whether the live camera card can actually run — authorized *and* the
    /// device has camera hardware (false on the Simulator).
    var canShowLiveCamera: Bool {
        authState.isAuthorized && hasCaptureDevice()
    }

    /// The explainer config for the current state, or nil when the live card can
    /// be shown. Authorized-but-no-hardware falls back to an "unavailable" state
    /// rather than a dead black preview.
    var explainerConfig: PermissionExplainerConfig? {
        switch authState {
        case .authorized:    return hasCaptureDevice() ? nil : .cameraUnavailable
        case .notDetermined: return .cameraNeeded
        case .denied:        return .cameraDenied
        case .restricted:    return .cameraRestricted
        }
    }
}
