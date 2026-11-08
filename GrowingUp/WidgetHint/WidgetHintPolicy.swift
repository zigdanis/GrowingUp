import Core
import Foundation

/// When the mosaic may show the strip that points to the Home Screen widget.
///
/// iOS has no API to add a widget for the user, so the app can only say once, quietly, that one exists. The strip waits
/// until the app has earned it: someone is on the widget, so it would show a person; the app has been used on a second
/// day and someone was visited in the viewer, so it is not part of the first look around. Days and visits are the ones
/// the rating prompt counts (`ReviewPromptState`). It stays out of the way of the rating request, a birthday celebration
/// and anything that went wrong, and it ends for good after a tap, ×, an installed widget, or ten launches without a tap.
struct WidgetHintPolicy: Equatable {
	var minimumActiveDays = 2
	var minimumViewerVisits = 1
	var maximumShownLaunches = 10
	/// How long after a rating request the strip stays away, so the two never meet.
	var quietAfterRatingRequest: TimeInterval = 86_400

	/// Whether the stored state and the use of the app allow the strip on this launch.
	func allowsLaunch(_ state: WidgetHintState, usage: ReviewPromptState, now: Date) -> Bool {
		guard !state.isRetired, state.shownLaunches < maximumShownLaunches, usage.activeDays >= minimumActiveDays,
			usage.viewerVisits >= minimumViewerVisits
		else { return false }
		guard let lastRequest = usage.requestDates.last else { return true }
		// A request dated ahead of `now`, after a clock change, is as recent as it gets.
		return now.timeIntervalSince(lastRequest) >= quietAfterRatingRequest
	}

	/// Whether `people` allow the strip now: someone is on the widget, and nobody whose birthday the app celebrates has
	/// it today, when the app belongs to them.
	func allowsPeople(_ people: [Person], now: Date, calendar: Calendar) -> Bool {
		people.contains(where: \.isOnWidget)
			&& !people.contains { $0.celebratesBirthdays && BirthdayStatus(birthday: $0.birthday, now: now, calendar: calendar).isToday }
	}

	/// Counts a launch the strip was shown on.
	func recordingShownLaunch(_ state: WidgetHintState) -> WidgetHintState {
		var next = state
		next.shownLaunches += 1
		return next
	}

	/// Ends the hint for good.
	func retiring(_ state: WidgetHintState) -> WidgetHintState {
		var next = state
		next.isRetired = true
		return next
	}
}
