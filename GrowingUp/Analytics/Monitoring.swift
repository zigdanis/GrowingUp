/// Builds the one analytics gateway the app uses from the configuration.
@MainActor
enum Monitoring {
	static func makeAnalytics(configuration: MonitoringConfiguration) -> AnalyticsGateway {
		var gateways: [AnalyticsGateway] = []
		if configuration.isDebugBuild {
			gateways.append(LoggingAnalyticsGateway())
		}
		if configuration.isReportingAllowed {
			// The crash reporter starts first, so a failure while PostHog starts is still captured.
			if let dsn = configuration.sentryDSN {
				gateways.append(SentryCrashReportingGateway(dsn: dsn, environment: configuration.environmentName))
			}
			if let apiKey = configuration.postHogAPIKey {
				gateways.append(
					PostHogAnalyticsGateway(apiKey: apiKey, host: configuration.postHogHost, environment: configuration.environmentName))
			}
		}
		switch gateways.count {
		case 0: return NoopAnalyticsGateway()
		case 1: return gateways[0]
		default: return CompositeAnalyticsGateway(gateways)
		}
	}
}
