import SwiftUI
import UIKit

/// The Settings rows about the app: its privacy policy, a mail to its developer that carries the version, and the version
/// itself.
struct SettingsAboutSection: View {
	static let privacyPolicy = URL(string: "https://ziganshin.pro/growing-up/privacy-policy")!
	static let supportAddress = "support@ziganshin.pro"

	let version: AppVersion

	var body: some View {
		Section {
			Link(destination: Self.privacyPolicy) {
				LabeledContent {
					Image(systemName: "arrow.up.right")
						.foregroundStyle(.secondary)
						.accessibilityHidden(true)
				} label: {
					Label("Privacy Policy", systemImage: "hand.raised")
				}
			}
			.accessibilityHint("Opens in Safari")
			.accessibilityIdentifier("settings.privacyPolicy")
			Link(destination: mailURL) {
				LabeledContent {
					Text(Self.supportAddress)
				} label: {
					Label("Contact the developer", systemImage: "envelope")
				}
			}
			.accessibilityHint("Opens your email app")
			.accessibilityIdentifier("settings.contact")
			.contextMenu {
				Button("Copy address", systemImage: "doc.on.doc") {
					UIPasteboard.general.string = Self.supportAddress
				}
			}
		} header: {
			Text("About")
		} footer: {
			Text("Version \(version.version) (\(version.build))")
		}
	}

	/// A new mail to the developer whose subject names the version, so a question arrives with it.
	private var mailURL: URL {
		var components = URLComponents()
		components.scheme = "mailto"
		components.path = Self.supportAddress
		components.queryItems = [URLQueryItem(name: "subject", value: String(localized: "GrowingUp \(version.display)"))]
		return components.url ?? URL(string: "mailto:\(Self.supportAddress)")!
	}
}
