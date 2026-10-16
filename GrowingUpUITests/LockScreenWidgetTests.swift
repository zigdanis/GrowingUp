import XCTest

@MainActor
final class LockScreenWidgetTests: XCTestCase {
	private var app: XCUIApplication!

	override func setUp() {
		super.setUp()
		continueAfterFailure = false
		app = XCUIApplication()
	}

	func testLockScreenWidgetsRenderTheFirstPinnedPersonInBothLanguages() {
		for locale in ["en", "ru"] {
			// Lock Screen widgets keep the Lock Screen's look whatever the app appearance, so they render once per language.
			for family in ["circular", "rectangular", "inline"] {
				launch(seed: .sixPinned, locale: locale, widgetFamily: family)
				XCTAssertTrue(widgetTile("Alice").waitForExistence(timeout: 5), family)
				XCTAssertFalse(widgetTile("Boris").exists, "\(family) should show only the first person")
				checkpoint("widget-\(family)-\(locale)")
				app.terminate()
			}
		}
	}

	func testLockScreenWidgetsCelebrateTheFirstPinnedBirthday() {
		// Alice, the first pinned person, was born on 16 January 2020.
		for (family, expected) in [("circular", "Birthday today"), ("rectangular", "Birthday today"), ("inline", "turns 7 today")] {
			launch(seed: .birthdays, widgetFamily: family, clock: "2027-01-16T08:00:00Z")
			let alice = widgetTile("Alice")
			XCTAssertTrue(alice.waitForExistence(timeout: 5), family)
			XCTAssertTrue(alice.label.contains(expected), "\(family): \(alice.label)")
			checkpoint("widget-\(family)-birthday-en")
			app.terminate()
		}
		launch(seed: .birthdays, locale: "ru", widgetFamily: "rectangular", clock: "2027-01-16T08:00:00Z")
		let russianAlice = widgetTile("Alice")
		XCTAssertTrue(russianAlice.waitForExistence(timeout: 5))
		XCTAssertTrue(russianAlice.label.contains("Сегодня день рождения"), russianAlice.label)
		checkpoint("widget-rectangular-birthday-ru")
		app.terminate()
	}

	func testLockScreenWidgetsInviteToAddSomeoneWhenNobodyIsPinned() {
		for family in ["circular", "rectangular", "inline"] {
			launch(seed: .empty, widgetFamily: family)
			let invitation = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Add someone")).firstMatch
			XCTAssertTrue(invitation.waitForExistence(timeout: 5), family)
			checkpoint("widget-\(family)-empty-en")
			app.terminate()
		}
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

	/// Lock Screen screenshots are reviewed as CI attachments; they have no pixel baseline.
	private func checkpoint(_ name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
