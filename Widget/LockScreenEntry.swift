import WidgetKit

/// The first pinned person at one moment of the Lock Screen timeline, or nobody when no one is pinned.
struct LockScreenEntry: TimelineEntry {
	let date: Date
	let person: WidgetPerson?
}
