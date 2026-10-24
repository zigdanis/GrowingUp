import XCTest

@MainActor
final class RemovalConfirmationTests: XCTestCase {
	/// Edit mode's last round control asks before removing, naming the person; its Cancel keeps both the person and the edit.
	func testRemovalAsksWithThePersonsName() {
		continueAfterFailure = false
		for (locale, appearance) in [("en", UITestAppearance.light)] {
			let app = XCUIApplication()
			launch(app, locale: locale, appearance: appearance)
			let first = app.buttons.matching(identifier: "people.tile").firstMatch
			XCTAssertTrue(first.waitForExistence(timeout: 10))
			first.tap()
			// A tap anywhere on the shown person turns the viewer into its edit mode.
			let overview = app.buttons["person.name"]
			XCTAssertTrue(overview.waitForExistence(timeout: 5))
			wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: overview)], timeout: 5)
			overview.tap()
			let remove = app.buttons["editor.remove"]
			XCTAssertTrue(remove.waitForExistence(timeout: 5))
			XCTAssertEqual(remove.label, locale == "ru" ? "Удалить" : "Remove", "VoiceOver names the control, not its glyph")
			remove.tap()
			let alert = app.alerts.firstMatch
			XCTAssertTrue(alert.waitForExistence(timeout: 5))
			XCTAssertEqual(alert.label, locale == "ru" ? "Удалить Alice?" : "Remove Alice?")
			XCTAssertTrue(alert.buttons[locale == "ru" ? "Удалить" : "Remove"].exists)
			let screenshot = app.screenshot()
			let attachment = XCTAttachment(screenshot: screenshot)
			attachment.name = "remove-confirmation-\(locale)-\(appearance.launchArgumentValue)"
			attachment.lifetime = .keepAlways
			add(attachment)
			alert.buttons[locale == "ru" ? "Отмена" : "Cancel"].tap()
			XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
			XCTAssertTrue(app.buttons["editor.save"].exists, "Declining the removal stays in edit mode")
			app.terminate()
		}
	}

	private func launch(_ app: XCUIApplication, locale: String, appearance: UITestAppearance) {
		let configuration = UITestConfiguration(
			identifier: UUID(), resetStore: true, seed: .pinned, failNextSave: false, appearance: appearance)
		app.launchEnvironment = [
			UITestConfiguration.environmentKey: configuration.encoded,
			"TZ": "UTC"
		]
		app.launchArguments = [
			"-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ru" ? "ru_RU" : "en_US",
			"-AppleInterfaceStyle", appearance.launchArgumentValue,
			"-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
		]
		app.launch()
	}
}
