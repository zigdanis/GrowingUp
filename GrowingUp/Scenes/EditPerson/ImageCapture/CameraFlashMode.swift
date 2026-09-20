import AVFoundation

/// Flash mode exposed to the camera card, decoupled from AVFoundation.
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

	var avFlashMode: AVCaptureDevice.FlashMode {
		switch self {
		case .off: return .off
		case .auto: return .auto
		case .on: return .on
		}
	}
}
