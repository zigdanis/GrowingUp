import Foundation

/// The silent haptics of previews, tests and UI-test launches.
@MainActor
final class NoHaptics: Haptics {
	nonisolated init() {}

	func play(_ event: HapticEvent) {}
	func celebrate(_ style: ConfettiStyle, startedAt start: Date) {}
	func stopCelebrating() {}
}
