//
//  PhotoAuthState.swift
//  GrowingUp
//
//  App-facing photo-library authorization state, decoupled from PhotoKit's
//  PHAuthorizationStatus so views switch on a small, Equatable enum.
//

import Photos

enum PhotoAuthState: Equatable {
	case notDetermined
	case full
	case limited
	case denied
	case restricted

	init(_ status: PHAuthorizationStatus) {
		switch status {
		case .authorized: self = .full
		case .limited: self = .limited
		case .denied: self = .denied
		case .restricted: self = .restricted
		case .notDetermined: self = .notDetermined
		@unknown default: self = .denied
		}
	}

	/// Whether a photo grid should be shown (full or limited access).
	var showsGrid: Bool {
		self == .full || self == .limited
	}
}
