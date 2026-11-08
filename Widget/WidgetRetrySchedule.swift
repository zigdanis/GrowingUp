import Foundation

/// When a widget that could not read the shared store asks WidgetKit to try again.
///
/// The usual cause, a store locked until the first unlock after a restart, clears within minutes, so the widget asks
/// for a reload after 15 minutes instead of at its next age change, which can be days away. WidgetKit documents about
/// 15–60 minutes between refreshes of a frequently viewed widget, so the request stays within its daily budget; the
/// system still decides the actual time. Each failed attempt asks again, and the first successful one returns to the
/// regular schedule, so the widget recovers without the app.
enum WidgetRetrySchedule {
	static let interval: TimeInterval = 15 * 60

	static func reloadDate(after now: Date) -> Date {
		now.addingTimeInterval(interval)
	}
}
