import Sentry

/// Crashes, hangs and handled failures through Sentry. Product events become breadcrumbs, so a crash report shows the
/// last steps before it; the people counts travel as a context block.
@MainActor
final class SentryCrashReportingGateway: AnalyticsGateway {
	/// The tag every handled failure carries; its error is sanitized before it is captured.
	nonisolated static let operationTag = "operation"
	/// The nearest error underneath a handled failure, as `domain code`, so its causes can be searched and told apart.
	nonisolated static let causeTag = "cause"

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
			// product events become breadcrumbs. Nothing hooks into views, taps or requests either.
			options.enableAutoBreadcrumbTracking = false
			options.enableSwizzling = false
			options.beforeSend = SentryCrashReportingGateway.scrubbed
		}
	}

	func track(_ event: AnalyticsEvent) {
		let crumb = Breadcrumb(level: .info, category: "product")
		crumb.message = event.name
		for (key, value) in event.properties {
			crumb.setData(value: value.anyValue, key: key)
		}
		SentrySDK.addBreadcrumb(crumb)
	}

	func report(_ failure: AnalyticsFailure) {
		let causes = failure.causes
		SentrySDK.capture(error: failure.sanitizedError) { scope in
			scope.setTag(value: failure.operation, key: Self.operationTag)
			if let cause = causes.first {
				scope.setTag(value: cause, key: Self.causeTag)
				scope.setContext(value: ["errors": causes], key: "causes")
			}
		}
	}

	func update(_ context: AnalyticsContext) {
		SentrySDK.configureScope { scope in
			scope.setContext(value: context.properties.anyValues, key: "app_state")
		}
	}

	/// A crash report can carry text the app never chose, and any of it can hold a person's name: an exception's reason
	/// and `userInfo`, a Swift runtime message, or strings Sentry reads from memory near the crash. Only the exception
	/// type, mechanism and stack travel; a handled failure keeps the value its sanitized error gave it. Sentry calls
	/// this on its own queue for every event.
	nonisolated static func scrubbed(_ event: Event) -> Event? {
		let isHandledFailure = event.tags?[operationTag] != nil
		for exception in event.exceptions ?? [] {
			if !isHandledFailure {
				exception.value = nil
				exception.mechanism?.desc = nil
			}
			exception.mechanism?.data = exception.mechanism?.data?.filter { $0.key != "crash_info_messages" }
		}
		event.context?["user info"] = nil
		return event
	}
}
