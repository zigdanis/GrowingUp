import Foundation

/// The app's version and build, as the bundle states them, such as `3.2` and `50`.
struct AppVersion: Equatable {
	let version: String
	let build: String

	static var current: AppVersion {
		let info = Bundle.main.infoDictionary
		return AppVersion(
			version: info?["CFBundleShortVersionString"] as? String ?? "", build: info?["CFBundleVersion"] as? String ?? "")
	}

	/// Both together, such as `3.2 (50)`, or the version alone without a build.
	var display: String {
		build.isEmpty ? version : "\(version) (\(build))"
	}
}
