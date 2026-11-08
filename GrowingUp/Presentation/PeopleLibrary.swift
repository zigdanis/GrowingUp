import Core
import Observation

/// Reads the stored people until one read succeeds, and tells the mosaic meanwhile whether they are still loading or
/// unavailable, so a failed read never looks like an empty library.
@MainActor
@Observable
final class PeopleLibrary {
	private(set) var state: PeopleLibraryState = .loading
	@ObservationIgnored private var isReading = false
	private let analytics: AnalyticsGateway

	init(analytics: AnalyticsGateway) {
		self.analytics = analytics
	}

	/// Reads the people with `fetch` unless a read already succeeded or is under way, such as at launch, from Retry or
	/// on every return to the app; nil when it did not read or was cancelled.
	///
	/// Only the first failure is reported: retries on each return to the app would repeat the same ticket.
	func read(_ fetch: () async throws -> [Person]) async -> Result<[Person], Error>? {
		guard state != .loaded, !isReading else { return nil }
		isReading = true
		defer { isReading = false }
		if case .unavailable = state { state = .unavailable(isRetrying: true) }
		do {
			let people = try await fetch()
			state = .loaded
			return .success(people)
		} catch is CancellationError {
			if case .unavailable = state { state = .unavailable(isRetrying: false) }
			return nil
		} catch {
			if state == .loading { analytics.report(AnalyticsFailure(operation: "load_people", error: error)) }
			state = .unavailable(isRetrying: false)
			return .failure(error)
		}
	}
}
