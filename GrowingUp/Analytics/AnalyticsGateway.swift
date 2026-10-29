/// One sink for product events and handled failures. The app talks to a single gateway; the composition root decides
/// which services stand behind it.
@MainActor
protocol AnalyticsGateway: AnyObject {
	func track(_ event: AnalyticsEvent)
	func report(_ failure: AnalyticsFailure)
	func update(_ context: AnalyticsContext)
}
