import XCTest

@testable import GrowingUp

/// Only a real device reports, and only to a service whose key is set; checks, captures and tests never start an SDK.
@MainActor
final class MonitoringConfigurationTests: XCTestCase {
	func testKeysAreReadFromTheInfoDictionaryAndEmptyMeansOff() {
		let configured = MonitoringConfiguration.current(
			info: ["PostHogAPIKey": " phc_key ", "PostHogHost": "", "SentryDSN": "https://key@o1.ingest.de.sentry.io/2"],
			launchEnvironment: [:])
		XCTAssertEqual(configured.postHogAPIKey, "phc_key")
		XCTAssertEqual(configured.postHogHost, "https://eu.i.posthog.com", "An empty host means the EU cloud")
		XCTAssertEqual(configured.sentryDSN, "https://key@o1.ingest.de.sentry.io/2")
		let empty = MonitoringConfiguration.current(info: ["PostHogAPIKey": "", "SentryDSN": "  "], launchEnvironment: [:])
		XCTAssertNil(empty.postHogAPIKey)
		XCTAssertNil(empty.sentryDSN)
	}

	func testChecksCapturesAndTestsNeverReport() {
		for environment in [
			["GROWINGUP_UI_TEST_CONFIGURATION": "e30="], ["GROWINGUP_APP_STORE_CAPTURE": "1"],
			["GROWINGUP_WIDGET_PREVIEW": "small"], ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]
		] {
			XCTAssertTrue(MonitoringConfiguration.isVerificationLaunch(environment), "\(environment)")
			XCTAssertFalse(configuration(isVerificationLaunch: MonitoringConfiguration.isVerificationLaunch(environment)).isReportingAllowed)
		}
		XCTAssertFalse(MonitoringConfiguration.isVerificationLaunch(["HOME": "/", "TMPDIR": "/tmp"]))
		XCTAssertFalse(configuration(isSimulator: true).isReportingAllowed, "The Simulator never reports")
		XCTAssertTrue(configuration().isReportingAllowed)
	}

	func testEnvironmentNames() {
		XCTAssertEqual(configuration(isDebugBuild: true).environmentName, "debug")
		XCTAssertEqual(configuration().environmentName, "production")
	}

	func testWithoutReportingOrKeysNoServiceStarts() {
		let silentDevice = Monitoring.makeAnalytics(configuration: configuration())
		XCTAssertTrue(silentDevice is NoopAnalyticsGateway, "A device without keys sends nothing")
		let simulator = Monitoring.makeAnalytics(
			configuration: configuration(postHogAPIKey: "phc_key", sentryDSN: "https://key@o1.ingest.de.sentry.io/2", isSimulator: true))
		XCTAssertTrue(simulator is NoopAnalyticsGateway, "The Simulator never starts an SDK, even with keys")
		let debugSimulator = Monitoring.makeAnalytics(
			configuration: configuration(postHogAPIKey: "phc_key", isDebugBuild: true, isSimulator: true))
		XCTAssertTrue(debugSimulator is LoggingAnalyticsGateway, "Debug builds only log on the Simulator")
	}

	private func configuration(
		postHogAPIKey: String? = nil, sentryDSN: String? = nil, isDebugBuild: Bool = false, isSimulator: Bool = false,
		isVerificationLaunch: Bool = false
	) -> MonitoringConfiguration {
		MonitoringConfiguration(
			postHogAPIKey: postHogAPIKey, sentryDSN: sentryDSN, isDebugBuild: isDebugBuild, isSimulator: isSimulator,
			isVerificationLaunch: isVerificationLaunch)
	}
}
