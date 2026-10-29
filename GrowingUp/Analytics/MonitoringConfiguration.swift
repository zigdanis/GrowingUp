import Foundation

/// Where the monitoring keys come from and whether this launch may report at all.
///
/// Keys live in build settings (`POSTHOG_API_KEY`, `POSTHOG_HOST`, `SENTRY_DSN`) that the Info.plist exposes; an empty
/// value leaves that service off. Only launches on a real device report: the Simulator, unit tests and every launch
/// with a `GROWINGUP_` variable (UI tests, App Store captures, widget previews) stay silent. A Debug build on a device
/// reports too, tagged `debug`, so the integration can be checked from Xcode. TestFlight and App Store installs share
/// the `production` tag; both SDKs tell them apart themselves (PostHog's `$is_testflight`, Sentry's `app.build_type`).
struct MonitoringConfiguration: Equatable {
	static let postHogAPIKeyInfoKey = "PostHogAPIKey"
	static let postHogHostInfoKey = "PostHogHost"
	static let sentryDSNInfoKey = "SentryDSN"
	static let defaultPostHogHost = "https://eu.i.posthog.com"

	var postHogAPIKey: String?
	var postHogHost: String
	var sentryDSN: String?
	var isDebugBuild: Bool
	var isSimulator: Bool
	var isVerificationLaunch: Bool

	init(
		postHogAPIKey: String? = nil, postHogHost: String? = nil, sentryDSN: String? = nil, isDebugBuild: Bool,
		isSimulator: Bool, isVerificationLaunch: Bool
	) {
		self.postHogAPIKey = Self.nonEmpty(postHogAPIKey)
		self.postHogHost = Self.nonEmpty(postHogHost) ?? Self.defaultPostHogHost
		self.sentryDSN = Self.nonEmpty(sentryDSN)
		self.isDebugBuild = isDebugBuild
		self.isSimulator = isSimulator
		self.isVerificationLaunch = isVerificationLaunch
	}

	/// Reads the keys from the main bundle and the build flags of this process.
	static func current(
		info: [String: Any] = Bundle.main.infoDictionary ?? [:],
		launchEnvironment: [String: String] = ProcessInfo.processInfo.environment
	) -> MonitoringConfiguration {
		#if DEBUG
			let isDebugBuild = true
		#else
			let isDebugBuild = false
		#endif
		#if targetEnvironment(simulator)
			let isSimulator = true
		#else
			let isSimulator = false
		#endif
		return MonitoringConfiguration(
			postHogAPIKey: info[postHogAPIKeyInfoKey] as? String, postHogHost: info[postHogHostInfoKey] as? String,
			sentryDSN: info[sentryDSNInfoKey] as? String, isDebugBuild: isDebugBuild, isSimulator: isSimulator,
			isVerificationLaunch: isVerificationLaunch(launchEnvironment))
	}

	/// UI tests, App Store captures and widget previews set `GROWINGUP_` variables, and XCTest hosts the unit tests in the
	/// app; none of them is a real user.
	static func isVerificationLaunch(_ environment: [String: String]) -> Bool {
		environment.keys.contains { $0.hasPrefix("GROWINGUP_") || $0.hasPrefix("XCTest") }
	}

	var isReportingAllowed: Bool {
		!isSimulator && !isVerificationLaunch
	}

	/// The environment tag both services show.
	var environmentName: String {
		isDebugBuild ? "debug" : "production"
	}

	private static func nonEmpty(_ value: String?) -> String? {
		guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
		return trimmed
	}
}
