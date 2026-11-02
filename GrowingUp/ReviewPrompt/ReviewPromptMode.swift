import Foundation

/// How a launch decides on the App Store rating request.
enum ReviewPromptMode: Equatable {
	/// Real use: `ReviewPromptPolicy` decides.
	case policy
	/// A manual check launched with `GROWINGUP_REVIEW_PROMPT=force`: every visit to the viewer asks, whatever the days,
	/// counts and limits say, and nothing is stored, so a development build shows the sheet on demand.
	case forced

	static let environmentKey = "GROWINGUP_REVIEW_PROMPT"

	/// The mode of a launch with `environment`; nil for verification launches (UI tests, App Store captures, widget
	/// previews, unit tests), which never ask.
	static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> ReviewPromptMode? {
		if environment[environmentKey] == "force" { return .forced }
		return MonitoringConfiguration.isVerificationLaunch(environment) ? nil : .policy
	}
}
