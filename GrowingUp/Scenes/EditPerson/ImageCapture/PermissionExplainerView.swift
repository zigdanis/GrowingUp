//
//  PermissionExplainerView.swift
//  GrowingUp
//
//  Reusable denied / restricted permission state. Shared by the photo grid and
//  (in a later PR) the camera card — only the copy, icon and action differ.
//

import SwiftUI
import UIKit

struct PermissionExplainerConfig {
  let icon: String
  let title: LocalizedStringKey
  let message: LocalizedStringKey
  /// Title for the primary button. `nil` hides the button (e.g. restricted,
  /// where the user cannot grant access anyway).
  let primaryButtonTitle: LocalizedStringKey?

  static let photosDenied = PermissionExplainerConfig(
    icon: "photo.on.rectangle.angled",
    title: "Photo access needed",
    message: "Allow access to your photos to choose a picture.",
    primaryButtonTitle: "Open Settings"
  )

  static let photosRestricted = PermissionExplainerConfig(
    icon: "lock.fill",
    title: "Photo access restricted",
    message: "Photo access is restricted on this device and can't be changed.",
    primaryButtonTitle: nil
  )

  static let cameraNeeded = PermissionExplainerConfig(
    icon: "camera.fill",
    title: "Camera access needed",
    message: "Allow access to your camera to take a picture.",
    primaryButtonTitle: "Allow Camera"
  )

  static let cameraDenied = PermissionExplainerConfig(
    icon: "camera.fill",
    title: "Camera access blocked",
    message: "Enable camera access in Settings to take a picture.",
    primaryButtonTitle: "Open Settings"
  )

  static let cameraRestricted = PermissionExplainerConfig(
    icon: "lock.fill",
    title: "Camera access restricted",
    message: "Camera access is restricted on this device and can't be changed.",
    primaryButtonTitle: nil
  )

  static let cameraUnavailable = PermissionExplainerConfig(
    icon: "video.slash.fill",
    title: "Camera unavailable",
    message: "No camera is available on this device. Choose a photo from your library instead.",
    primaryButtonTitle: nil
  )
}

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
