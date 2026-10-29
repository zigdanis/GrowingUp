@testable import GrowingUp

/// Records what the app would send, so tests can check events, failures and context without any SDK.
@MainActor
final class AnalyticsGatewaySpy: AnalyticsGateway {
	private(set) var events: [AnalyticsEvent] = []
	private(set) var failures: [AnalyticsFailure] = []
	private(set) var contexts: [AnalyticsContext] = []
	/// The counts the services held when each event went out, in the order of `events`.
	private(set) var contextsAtEvents: [AnalyticsContext?] = []

	var operations: [String] { failures.map(\.operation) }

	func track(_ event: AnalyticsEvent) {
		events.append(event)
		contextsAtEvents.append(contexts.last)
	}
	func report(_ failure: AnalyticsFailure) { failures.append(failure) }
	func update(_ context: AnalyticsContext) { contexts.append(context) }
}
