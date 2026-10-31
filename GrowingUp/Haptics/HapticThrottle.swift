import Foundation

/// Keeps each event to its `HapticEvent.minimumInterval`: a play inside that time since the event last played is dropped.
struct HapticThrottle {
	private var lastPlayed: [HapticEvent: Date] = [:]

	/// Whether `event` may play at `date`; an allowed play starts the event's interval afresh.
	mutating func allows(_ event: HapticEvent, at date: Date) -> Bool {
		guard event.minimumInterval > 0 else { return true }
		if let last = lastPlayed[event], date.timeIntervalSince(last) < event.minimumInterval { return false }
		lastPlayed[event] = date
		return true
	}
}
