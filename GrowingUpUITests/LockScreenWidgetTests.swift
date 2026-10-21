import XCTest

@MainActor
final class LockScreenWidgetTests: XCTestCase {
	private var app: XCUIApplication!

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testLockScreenWidgetFamiliesAndStates() {
		launch(seed: .sixPinned, widgetFamily: "circular")
		XCTAssertTrue(widgetTile("Alice").waitForExistence(timeout: 5))
		XCTAssertFalse(widgetTile("Boris").exists)
		checkpoint("widget-circular-en")
		app.terminate()
		launch(seed: .birthdays, locale: "ru", widgetFamily: "rectangular", clock: "2027-01-16T08:00:00Z")
		let alice = widgetTile("Alice")
		XCTAssertTrue(alice.waitForExistence(timeout: 5))
		XCTAssertTrue(alice.label.contains("Сегодня день рождения"), alice.label)
		checkpoint("widget-rectangular-birthday-ru")
		app.terminate()
		launch(seed: .empty, widgetFamily: "inline")
		let invitation = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Add someone")).firstMatch
		XCTAssertTrue(invitation.waitForExistence(timeout: 5))
		checkpoint("widget-inline-empty-en")
	}

	private func launch(seed: UITestSeed, locale: String = "en", widgetFamily: String, clock: String? = nil) {
		let configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: seed, failNextSave: false, appearance: .light)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"GROWINGUP_WIDGET_PREVIEW": widgetFamily,
			"TZ": "UTC"
		]
		if let clock { app.launchEnvironment["GROWINGUP_BIRTHDAY_NOW"] = clock }
		app.launchArguments = [
			"-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ru" ? "ru_RU" : "en_US",
			"-AppleInterfaceStyle", UITestAppearance.light.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
		XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "widget.preview").firstMatch.waitForExistence(timeout: 10))
	}

	private func widgetTile(_ name: String) -> XCUIElement {
		app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
	}

	/// Screenshots are retained for review as CI attachments.
	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
