/// The gateway for tests, previews, UI-test launches and builds without any monitoring service.
@MainActor
final class NoopAnalyticsGateway: AnalyticsGateway {
	nonisolated init() {}

	func track(_ event: AnalyticsEvent) {}
	func report(_ failure: AnalyticsFailure) {}
	func update(_ context: AnalyticsContext) {}
}
