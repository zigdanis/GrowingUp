import XCTest

@MainActor
final class RemovalConfirmationTests: XCTestCase {
	func testRemovalConfirmationStaysNearButton() {
		continueAfterFailure = false
		for (locale, appearance) in [("en", UITestAppearance.light), ("ru", .dark)] {
			let app = XCUIApplication()
			launch(app, locale: locale, appearance: appearance)
			let overview = app.descendants(matching: .any).matching(identifier: "person.edit").firstMatch
			XCTAssertTrue(overview.waitForExistence(timeout: 10))
			overview.tap()
			let remove = app.buttons["editor.remove"]
			XCTAssertTrue(remove.waitForExistence(timeout: 5))
			let sourceFrame = remove.frame
			remove.tap()
			let localizedLabel = locale == "ru" ? "Удалить" : "Remove"
			let confirmation = app.buttons.matching(
				NSPredicate(format: "label == %@ AND identifier != %@", localizedLabel, "editor.remove")
			).firstMatch
			XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
			let screenshot = app.screenshot()
			let attachment = XCTAttachment(screenshot: screenshot)
			attachment.name = "remove-confirmation-\(locale)-\(appearance.launchArgumentValue)"
			attachment.lifetime = .keepAlways
			add(attachment)
			if #available(iOS 26.0, *) {
				let actionFrame = confirmation.frame
				let verticalGap = max(0, max(sourceFrame.minY - actionFrame.maxY, actionFrame.minY - sourceFrame.maxY))
				XCTAssertLessThan(verticalGap, 100, "Removal confirmation must stay beside its source button")
				XCTAssertTrue(sourceFrame.minX...sourceFrame.maxX ~= actionFrame.midX)
			}
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
