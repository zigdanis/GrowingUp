import Foundation

/// What the app remembers between launches about the Home Screen widget hint.
struct WidgetHintState: Codable, Equatable {
	/// The hint is gone for good: it was tapped or closed, a GrowingUp widget was found, or it was shown enough.
	var isRetired = false
	/// Launches the strip was shown on; see `WidgetHintPolicy.maximumShownLaunches`.
	var shownLaunches = 0

	init(isRetired: Bool = false, shownLaunches: Int = 0) {
		self.isRetired = isRetired
		self.shownLaunches = shownLaunches
	}

	/// Reads each value on its own, so a value stored by another version, with fields missing or added, keeps the hint
	/// retired rather than showing it again.
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isRetired = try container.decodeIfPresent(Bool.self, forKey: .isRetired) ?? false
		shownLaunches = try container.decodeIfPresent(Int.self, forKey: .shownLaunches) ?? 0
	}
}
