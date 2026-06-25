//
//  CameraAuthState.swift
//  GrowingUp
//
//  App-facing camera authorization state, decoupled from AVFoundation's
//  AVAuthorizationStatus so views switch on a small, Equatable enum — the
//  mirror of PhotoAuthState for the camera source.
//

import AVFoundation

enum CameraAuthState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted

    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .authorized:    self = .authorized
        case .denied:        self = .denied
        case .restricted:    self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default:    self = .denied
        }
    }

    /// Whether the live camera preview/capture surface can be shown.
    var isAuthorized: Bool {
        self == .authorized
    }
}
