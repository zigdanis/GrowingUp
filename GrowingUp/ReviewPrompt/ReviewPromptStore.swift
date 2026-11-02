import Foundation

/// Keeps `ReviewPromptState` in the app's own `UserDefaults`; the widget never asks for a rating, so it stays out of the
/// shared App Group.
@MainActor
final class ReviewPromptStore {
	static let key = "reviewPrompt"
	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	/// The stored state; a missing or unreadable value starts over from nothing.
	var state: ReviewPromptState {
		get {
			guard let data = defaults.data(forKey: Self.key) else { return ReviewPromptState() }
			return (try? JSONDecoder().decode(ReviewPromptState.self, from: data)) ?? ReviewPromptState()
		}
		set {
			guard let data = try? JSONEncoder().encode(newValue) else { return }
			defaults.set(data, forKey: Self.key)
		}
	}
}
