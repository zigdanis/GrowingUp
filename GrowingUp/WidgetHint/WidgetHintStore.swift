import Foundation

/// Keeps `WidgetHintState` in the app's own `UserDefaults`, next to the rating prompt's state, so it survives updates.
@MainActor
final class WidgetHintStore {
	static let key = "widgetHint"
	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	/// The stored state; a missing value starts from nothing. An unreadable one counts as retired, so a damaged value
	/// never brings the hint back.
	var state: WidgetHintState {
		get {
			guard let data = defaults.data(forKey: Self.key) else { return WidgetHintState() }
			return (try? JSONDecoder().decode(WidgetHintState.self, from: data)) ?? WidgetHintState(isRetired: true)
		}
		set {
			guard let data = try? JSONEncoder().encode(newValue) else { return }
			defaults.set(data, forKey: Self.key)
		}
	}
}
