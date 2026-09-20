import SwiftUI

struct PermissionExplainerConfig {
	let icon: String
	let title: LocalizedStringKey
	let message: LocalizedStringKey
	let primaryButtonTitle: LocalizedStringKey?

	static let photosDenied = PermissionExplainerConfig(
		icon: "photo.on.rectangle.angled", title: "Photo access needed",
		message: "Allow access to your photos to choose a picture.", primaryButtonTitle: "Open Settings")
	static let photosRestricted = PermissionExplainerConfig(
		icon: "lock.fill", title: "Photo access restricted",
		message: "Photo access is restricted on this device and can't be changed.", primaryButtonTitle: nil)
	static let cameraNeeded = PermissionExplainerConfig(
		icon: "camera.fill", title: "Camera access needed",
		message: "Allow access to your camera to take a picture.", primaryButtonTitle: "Allow Camera")
	static let cameraDenied = PermissionExplainerConfig(
		icon: "camera.fill", title: "Camera access blocked",
		message: "Enable camera access in Settings to take a picture.", primaryButtonTitle: "Open Settings")
	static let cameraRestricted = PermissionExplainerConfig(
		icon: "lock.fill", title: "Camera access restricted",
		message: "Camera access is restricted on this device and can't be changed.", primaryButtonTitle: nil)
	static let cameraUnavailable = PermissionExplainerConfig(
		icon: "video.slash.fill", title: "Camera unavailable",
		message: "No camera is available on this device. Choose a photo from your library instead.", primaryButtonTitle: nil)
}
