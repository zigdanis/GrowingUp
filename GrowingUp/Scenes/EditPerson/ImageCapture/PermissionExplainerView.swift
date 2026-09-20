//
//  PermissionExplainerView.swift
//  GrowingUp
//
//  Reusable denied / restricted permission state. Shared by the photo grid and
//  (in a later PR) the camera card — only the copy, icon and action differ.
//

import SwiftUI
import UIKit

struct PermissionExplainerView: View {
	let config: PermissionExplainerConfig
	/// Custom primary-button action. When nil the button opens Settings —
	/// the right move for a denied state. The camera-needed (not-determined)
	/// state passes a closure that triggers the system permission prompt.
	var primaryAction: (() -> Void)?

	@Environment(\.openURL)
	private var openURL

	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: config.icon)
				.font(.system(size: 48))
				.foregroundStyle(.secondary)
			Text(config.title)
				.font(.title3.weight(.semibold))
				.multilineTextAlignment(.center)
			Text(config.message)
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
			if let buttonTitle = config.primaryButtonTitle {
				Button(buttonTitle) {
					if let primaryAction {
						primaryAction()
					} else {
						openSettings()
					}
				}
				.buttonStyle(.borderedProminent)
				.padding(.top, 4)
			}
		}
		.padding(32)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private func openSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
		openURL(url)
	}
}
