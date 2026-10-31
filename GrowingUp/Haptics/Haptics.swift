import Foundation

/// The app's touch feedback. Views read it from the environment, so previews, tests and UI-test launches stay silent and
/// only the app's root installs the device's Taptic Engine.
@MainActor
protocol Haptics: AnyObject, Sendable {
	func play(_ event: HapticEvent)
	/// Plays the birthday pattern of `style` in step with confetti that started falling at `start`; the part of it
	/// already past is skipped, never played late.
	func celebrate(_ style: ConfettiStyle, startedAt start: Date)
	func stopCelebrating()
}
