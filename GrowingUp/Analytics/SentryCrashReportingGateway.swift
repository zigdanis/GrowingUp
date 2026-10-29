import Sentry

/// Crashes, hangs and handled failures through Sentry. Product events become breadcrumbs, so a crash report shows the
/// last steps before it; the people counts travel as a context block.
@MainActor
final class SentryCrashReportingGateway: AnalyticsGateway {
	init(dsn: String, environment: String) {
		SentrySDK.start { options in
			options.dsn = dsn
			options.environment = environment
			options.enableAutoSessionTracking = true
			// No IP addresses, screenshots or view hierarchies: a report never shows a person's name, birthday or photo.
			options.sendDefaultPii = false
			options.attachScreenshot = false
			options.attachViewHierarchy = false
			// Automatic breadcrumbs record view titles and accessibility labels, which name people. Only the gateway's fixed
			// product events become breadcrumbs.
			options.enableAutoBreadcrumbTracking = false
			options.enableNetworkBreadcrumbs = false
			options.enableCaptureFailedRequests = false
		}
	}

	func track(_ event: AnalyticsEvent) {
		let crumb = Breadcrumb(level: .info, category: "product")
		crumb.message = event.name
		crumb.data = event.properties.anyValues
		SentrySDK.addBreadcrumb(crumb)
	}

	func report(_ failure: AnalyticsFailure) {
		SentrySDK.capture(error: failure.sanitizedError) { scope in
			scope.setTag(value: failure.operation, key: "operation")
		}
	}

	func update(_ context: AnalyticsContext) {
		SentrySDK.configureScope { scope in
			scope.setContext(value: context.properties.anyValues, key: "app_state")
		}
	}
}
