import OSLog

/// Writes every event and failure to the unified log in Debug builds, so instrumentation can be checked in Console or
/// with `log stream --predicate 'subsystem == "pro.ziganshin.GrowingUp"'`.
@MainActor
final class LoggingAnalyticsGateway: AnalyticsGateway {
	private static let logger = Logger(subsystem: "pro.ziganshin.GrowingUp", category: "Analytics")

	func track(_ event: AnalyticsEvent) {
		Self.logger.notice("event \(event.name, privacy: .public) \(Self.describe(event.properties), privacy: .public)")
	}

	func report(_ failure: AnalyticsFailure) {
		let reason = failure.sanitizedError.localizedDescription
		Self.logger.error("failure \(failure.operation, privacy: .public): \(reason, privacy: .public)")
	}

	func update(_ context: AnalyticsContext) {
		Self.logger.notice("context \(Self.describe(context.properties), privacy: .public)")
	}

	private static func describe(_ properties: [String: AnalyticsValue]) -> String {
		properties.keys.sorted().map { key in "\(key)=\(properties[key]?.anyValue ?? "")" }.joined(separator: " ")
	}
}
