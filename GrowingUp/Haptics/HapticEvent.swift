import Foundation

/// What the person just did that is worth feeling. Haptics confirm a change they caused, one feedback per gesture, and
/// leave browsing quiet: paging through people, scrolling the mosaic and opening a menu play nothing.
enum HapticEvent: CaseIterable {
	case tileOpened
	case addPerson
	case editEntered
	case cancelled
	case saved
	case toggledOn
	case toggledOff
	/// A photo picked from the grid, the camera flipped or its flash changed, or a birthday capsule opening its picker.
	case selectionChanged
	case shutter
	case cropConfirmed
	/// A dragged or pinched photo pulled past the edge of its crop frame, once per gesture.
	case cropEdgeHit
	case reorderLifted
	/// A dragged tile taking another slot of the mosaic, or VoiceOver moving one a place along.
	case slotSwapped
	case dropped
	case reorderFinished
	case removalConfirmationShown
	case removed
	case photoRemoved
	case failure

	var feedback: HapticFeedback {
		switch self {
		case .tileOpened, .reorderFinished: .impact(.light, intensity: 0.6)
		case .addPerson: .impact(.soft, intensity: 0.7)
		case .editEntered, .cropConfirmed: .impact(.light, intensity: 0.7)
		case .cancelled, .toggledOff: .impact(.soft, intensity: 0.5)
		case .saved: .notification(.success)
		case .toggledOn: .impact(.rigid, intensity: 0.7)
		case .selectionChanged, .slotSwapped: .selection
		case .shutter: .impact(.medium, intensity: 0.9)
		case .cropEdgeHit: .impact(.soft, intensity: 0.4)
		case .reorderLifted: .impact(.medium, intensity: 1)
		case .dropped: .impact(.light, intensity: 0.8)
		case .removalConfirmationShown: .notification(.warning)
		case .removed: .impact(.soft, intensity: 0.9)
		case .photoRemoved: .impact(.soft, intensity: 0.6)
		case .failure: .notification(.error)
		}
	}

	/// The shortest time between two plays of the event. A tile dragged quickly across the mosaic passes several slots in
	/// a moment, which would otherwise buzz rather than tick; every other event plays each time.
	var minimumInterval: TimeInterval {
		switch self {
		case .slotSwapped: 0.12
		default: 0
		}
	}
}
