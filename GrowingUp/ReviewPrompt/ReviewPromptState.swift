import Foundation

/// What the app remembers between launches to time the App Store rating request.
struct ReviewPromptState: Codable, Equatable {
	/// Distinct calendar days the app was in the foreground, the first one included.
	var activeDays = 0
	/// The last of those days as `yyyy-MM-dd` in the user's calendar.
	var lastActiveDay: String?
	/// The first of those days: the first launch of a build that counts them, also for people who installed earlier.
	var firstActiveDate: Date?
	/// Closed viewers that had shown someone for a few seconds; see `ReviewPromptPolicy.isVisit(from:to:)`.
	var viewerVisits = 0
	/// App-initiated requests, oldest first; recording a new one drops those older than 365 days.
	var requestDates: [Date] = []
	/// Every app-initiated request ever made.
	var requestCount = 0
	var lastRequestVersion: String?
	/// `activeDays` at the last request, so asking again needs new days of use.
	var activeDaysAtLastRequest = 0
}
