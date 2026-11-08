import Core
import Observation

/// Reads the stored people until one read succeeds, and tells the mosaic meanwhile whether they are still loading or
/// unavailable, so a failed read never looks like an empty library.
@MainActor
@Observable
final class PeopleLibrary {
	private(set) var state: PeopleLibraryState = .loading
	/// The read under way. It runs to its end whoever asked for it is cancelled, as when the app leaves the foreground:
	/// a request that came meanwhile only waited for it, so an abandoned read would leave nobody to read again.
	@ObservationIgnored private var reading: Task<Result<[Person], Error>?, Never>?
	private let fetch: () async throws -> [Person]
	private let analytics: AnalyticsGateway

	init(fetch: @escaping () async throws -> [Person], analytics: AnalyticsGateway) {
		self.fetch = fetch
		self.analytics = analytics
	}

	/// Reads the people unless a read already succeeded, such as at launch, from Retry or on every return to the app;
	/// nil when they were loaded already, when another read was under way, which this one waits for, or when the read
	/// was cancelled.
	///
	/// Only the first failure is reported: retries on each return to the app would repeat the same ticket.
	func read() async -> Result<[Person], Error>? {
		guard state != .loaded else { return nil }
		if let reading {
			_ = await reading.value
			return nil
		}
		if case .unavailable = state { state = .unavailable(isRetrying: true) }
		let read = Task {
			let result = await self.perform()
			self.reading = nil
			return result
		}
		reading = read
		return await read.value
	}

	private func perform() async -> Result<[Person], Error>? {
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
