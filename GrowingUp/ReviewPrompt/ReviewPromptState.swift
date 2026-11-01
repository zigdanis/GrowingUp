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

	init() {}

	/// Reads each value on its own, so a value stored by another version, with fields missing or added, keeps the request
	/// history and its limits rather than starting over.
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		activeDays = try container.decodeIfPresent(Int.self, forKey: .activeDays) ?? 0
		lastActiveDay = try container.decodeIfPresent(String.self, forKey: .lastActiveDay)
		firstActiveDate = try container.decodeIfPresent(Date.self, forKey: .firstActiveDate)
		viewerVisits = try container.decodeIfPresent(Int.self, forKey: .viewerVisits) ?? 0
		requestDates = try container.decodeIfPresent([Date].self, forKey: .requestDates) ?? []
		requestCount = try container.decodeIfPresent(Int.self, forKey: .requestCount) ?? 0
		lastRequestVersion = try container.decodeIfPresent(String.self, forKey: .lastRequestVersion)
		activeDaysAtLastRequest = try container.decodeIfPresent(Int.self, forKey: .activeDaysAtLastRequest) ?? 0
	}
}
