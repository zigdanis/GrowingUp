//
//  AVAuthorizationStatus+ImageCapture.swift
//  GrowingUp
//
//  Small camera-permission helpers used by the image-capture flow.
//

import AVFoundation

extension AVAuthorizationStatus {
    /// Whether the live camera preview/capture surface can be shown.
    var isCameraAuthorized: Bool {
        self == .authorized
    }
}
