import Foundation

/// How a launch decides on the Home Screen widget hint.
enum WidgetHintMode: Equatable {
	/// Real use: `WidgetHintPolicy` decides.
	case policy
	/// A manual check launched with `GROWINGUP_WIDGET_HINT=force`: the strip shows whatever the days, visits, launches,
	/// installed widgets and rating requests say, and nothing is stored, so screenshots can show it on demand. Someone
	/// must still be on the widget, and reordering, a birthday, a tap or × still hide it.
	case forced

	static let environmentKey = "GROWINGUP_WIDGET_HINT"

	/// The mode of a launch with `environment`; nil for other verification launches (UI tests, App Store captures, widget
	/// previews, unit tests), which never show the hint.
	static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> WidgetHintMode? {
		if environment[environmentKey] == "force" { return .forced }
		return MonitoringConfiguration.isVerificationLaunch(environment) ? nil : .policy
	}
}
