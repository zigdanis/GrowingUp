import PostHog

/// Product analytics through PostHog. Events carry only the categories and counts in `AnalyticsEvent`; the SDK adds its
/// anonymous installation ID, device model, OS and app version, and its own "Application Opened / Backgrounded /
/// Installed / Updated" lifecycle events.
@MainActor
final class PostHogAnalyticsGateway: AnalyticsGateway {
	init(apiKey: String, host: String, environment: String) {
		let config = PostHogConfig(projectToken: apiKey, host: host)
		config.captureApplicationLifecycleEvents = true
		// Every automatic capture that watches the screen hooks in by swizzling: screen names, tapped labels, rage clicks,
		// session replay and push opens. A person's page and tile show their name, so none of them is installed;
		// screens are explicit events.
		config.enableSwizzling = false
		config.captureScreenViews = false
		config.captureElementInteractions = false
		config.rageClickConfig.enabled = false
		config.sessionReplay = false
		config.capturePushNotificationSubscriptions = false
		config.capturePushNotificationOpened = false
		// Sentry owns crash reports.
		config.errorTrackingConfig.autoCapture = false
		// Feature flags are not used, so the app never calls the flags endpoint.
		config.preloadFeatureFlags = false
		config.sendFeatureFlagEvent = false
		// Events stay anonymous: the app never identifies anyone, so no person profiles exist.
		config.personProfiles = .identifiedOnly
		// PostHog would otherwise derive a city from each event's IP address.
		config.disableGeoIp = true
		PostHogSDK.shared.setup(config)
		PostHogSDK.shared.register(["app_environment": environment])
	}

	func track(_ event: AnalyticsEvent) {
		PostHogSDK.shared.capture(event.name, properties: event.properties.anyValues)
	}

	/// Failures go to the crash reporter; PostHog keeps the product picture only.
	func report(_ failure: AnalyticsFailure) {}

	func update(_ context: AnalyticsContext) {
		PostHogSDK.shared.register(context.properties.anyValues)
	}
}
