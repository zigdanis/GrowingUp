import Core
import Foundation

/// When to ask for an App Store rating.
///
/// The system sheet is the only prompt (App Review Guideline 5.6.1 forbids custom ones and filtering by sentiment), so
/// the odds of a good rating come from the moment: someone who has come back on a third separate day, at least a week
/// after the first, keeps several people with photos and has just closed the viewer after looking at someone, with no
/// failure or removal in the session. The request never lands on the viewer itself, so it never covers a birthday
/// celebration and its timing says nothing about anyone's birthday. Apple shows the sheet at most three times a year and
/// never in TestFlight; this policy asks less often: once per app version, at least 120 days apart, and again only
/// after a few new days of use.
struct ReviewPromptPolicy: Equatable {
	var minimumActiveDays = 3
	var minimumDaysSinceFirstActive = 7
	var minimumViewerVisits = 5
	/// How long the viewer must have shown someone for its close to count as a visit, so a tap in and out doesn't.
	var minimumVisitDuration: TimeInterval = 3
	var minimumPeople = 2
	var minimumPeopleWithPhoto = 1
	var cooldownDays = 120
	var maximumRequestsPerYear = 3
	var newActiveDaysBeforeAskingAgain = 3

	private static let secondsPerDay: TimeInterval = 86_400

	static func dayKey(for date: Date, calendar: Calendar) -> String {
		let components = calendar.dateComponents([.year, .month, .day], from: date)
		return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
	}

	/// Counts the day of `now` once, however many times the app comes to the foreground that day.
	func recordingActiveDay(_ state: ReviewPromptState, now: Date, calendar: Calendar) -> ReviewPromptState {
		let day = Self.dayKey(for: now, calendar: calendar)
		guard state.lastActiveDay != day else { return state }
		var next = state
		next.lastActiveDay = day
		next.activeDays += 1
		if next.firstActiveDate == nil { next.firstActiveDate = now }
		return next
	}

	/// Whether a viewer open from `opened` to `closed` showed someone long enough to count.
	func isVisit(from opened: Date, to closed: Date) -> Bool {
		closed.timeIntervalSince(opened) >= minimumVisitDuration
	}

	func recordingViewerVisit(_ state: ReviewPromptState) -> ReviewPromptState {
		var next = state
		next.viewerVisits += 1
		return next
	}

	/// Whether a visit that ended now, with `people` stored, is the moment to ask.
	func shouldRequest(_ state: ReviewPromptState, now: Date, calendar: Calendar, version: String, people: [Person]) -> Bool {
		guard state.activeDays >= minimumActiveDays,
			daysSinceFirstActive(state, now: now, calendar: calendar) >= minimumDaysSinceFirstActive,
			state.viewerVisits >= minimumViewerVisits, people.count >= minimumPeople,
			people.filter(\.hasPhoto).count >= minimumPeopleWithPhoto
		else { return false }
		guard let lastRequest = state.requestDates.last else { return true }
		return state.lastRequestVersion != version
			&& now.timeIntervalSince(lastRequest) >= Double(cooldownDays) * Self.secondsPerDay
			&& requestsInLastYear(state, now: now) < maximumRequestsPerYear
			&& state.activeDays - state.activeDaysAtLastRequest >= newActiveDaysBeforeAskingAgain
	}

	func recordingRequest(_ state: ReviewPromptState, now: Date, version: String) -> ReviewPromptState {
		var next = state
		let yearAgo = now.addingTimeInterval(-365 * Self.secondsPerDay)
		next.requestDates = state.requestDates.filter { $0 > yearAgo } + [now]
		next.requestCount += 1
		next.lastRequestVersion = version
		next.activeDaysAtLastRequest = state.activeDays
		return next
	}

	/// Whole calendar days from the first active day to `now`.
	func daysSinceFirstActive(_ state: ReviewPromptState, now: Date, calendar: Calendar) -> Int {
		guard let first = state.firstActiveDate else { return 0 }
		let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: now)).day
		return max(days ?? 0, 0)
	}

	private func requestsInLastYear(_ state: ReviewPromptState, now: Date) -> Int {
		let yearAgo = now.addingTimeInterval(-365 * Self.secondsPerDay)
		return state.requestDates.filter { $0 > yearAgo }.count
	}
}
