/// One feedback the Taptic Engine plays, described without UIKit so the mapping from events stays testable.
enum HapticFeedback: Equatable {
	/// A single tap of `HapticImpact`'s feel at `intensity`, from 0 to 1.
	case impact(HapticImpact, intensity: Double)
	/// The faint tick of a value moving to the next one, as a picker's wheel gives.
	case selection
	case notification(HapticNotification)
}
