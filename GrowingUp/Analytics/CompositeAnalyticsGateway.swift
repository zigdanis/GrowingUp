/// Fans every call out to each configured service, so call sites never know how many there are.
@MainActor
final class CompositeAnalyticsGateway: AnalyticsGateway {
	private let gateways: [AnalyticsGateway]

	init(_ gateways: [AnalyticsGateway]) {
		self.gateways = gateways
	}

	func track(_ event: AnalyticsEvent) {
		for gateway in gateways { gateway.track(event) }
	}

	func report(_ failure: AnalyticsFailure) {
		for gateway in gateways { gateway.report(failure) }
	}

	func update(_ context: AnalyticsContext) {
		for gateway in gateways { gateway.update(context) }
	}
}
