import UIKit

/// The device's Taptic Engine. UIKit's feedback generators play the app's events, each kept warm after it plays so a
/// quick next one lands on time; `BirthdayHapticEngine` plays the birthday celebrations.
@MainActor
final class SystemHaptics: Haptics {
	private var impacts: [HapticImpact: UIImpactFeedbackGenerator] = [:]
	private let selection = UISelectionFeedbackGenerator()
	private let notification = UINotificationFeedbackGenerator()
	private let birthday = BirthdayHapticEngine()
	private var throttle = HapticThrottle()
	private let now: () -> Date

	init(now: @escaping () -> Date = Date.init) {
		self.now = now
	}

	func play(_ event: HapticEvent) {
		guard throttle.allows(event, at: now()) else { return }
		switch event.feedback {
		case .impact(let impact, let intensity):
			let generator = impactGenerator(for: impact)
			generator.impactOccurred(intensity: CGFloat(min(max(intensity, 0), 1)))
			generator.prepare()
		case .selection:
			selection.selectionChanged()
			selection.prepare()
		case .notification(let outcome):
			notification.notificationOccurred(Self.feedbackType(of: outcome))
			notification.prepare()
		}
	}

	func celebrate(_ style: ConfettiStyle, startedAt start: Date) {
		birthday.play(BirthdayHapticPattern.pulses(for: style), startedAt: start)
	}

	func stopCelebrating() {
		birthday.stop()
	}

	/// One generator per feel, made the first time it plays.
	private func impactGenerator(for impact: HapticImpact) -> UIImpactFeedbackGenerator {
		if let generator = impacts[impact] { return generator }
		let generator = UIImpactFeedbackGenerator(style: Self.style(of: impact))
		impacts[impact] = generator
		return generator
	}

	private static func style(of impact: HapticImpact) -> UIImpactFeedbackGenerator.FeedbackStyle {
		switch impact {
		case .light: .light
		case .medium: .medium
		case .soft: .soft
		case .rigid: .rigid
		}
	}

	private static func feedbackType(of notification: HapticNotification) -> UINotificationFeedbackGenerator.FeedbackType {
		switch notification {
		case .success: .success
		case .warning: .warning
		case .error: .error
		}
	}
}
