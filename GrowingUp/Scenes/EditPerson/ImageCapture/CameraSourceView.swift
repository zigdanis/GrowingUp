import SwiftUI

struct CameraSourceView: View {
	let cameraModel: CameraSourceModel
	let onCapture: (UIImage) -> Void
	let onBack: () -> Void

	var body: some View {
		if cameraModel.canShowLiveCamera {
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
			}
		}
	}

	private func requestAccess() { Task { await cameraModel.requestIfNeeded() } }
}
