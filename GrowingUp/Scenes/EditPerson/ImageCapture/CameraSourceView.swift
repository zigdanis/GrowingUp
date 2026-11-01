import SwiftUI

struct CameraSourceView: View {
	let cameraModel: CameraSourceModel
	/// A still the camera card shows in place of the live camera; see `CameraCardView.standIn`.
	var standIn: UIImage?
	let onCapture: (UIImage) -> Void
	let onBack: () -> Void

	var body: some View {
		if let standIn {
			CameraCardView(controller: cameraModel.controller, standIn: standIn, onCapture: onCapture, onClose: onBack)
		} else if cameraModel.canShowLiveCamera {
			CameraCardView(controller: cameraModel.controller, onCapture: onCapture, onClose: onBack)
		} else if let config = cameraModel.explainerConfig {
			ZStack(alignment: .topLeading) {
				PermissionExplainerView(
					config: config,
					primaryAction: cameraModel.authState == .notDetermined ? requestAccess : nil)
				Button(action: onBack) {
					Image(systemName: "chevron.left").font(.title3.weight(.semibold)).padding(16)
				}
				.accessibilityLabel(Text("Back"))
				.accessibilityIdentifier("camera.back")
			}
		}
	}

	private func requestAccess() { Task { await cameraModel.requestIfNeeded() } }
}
