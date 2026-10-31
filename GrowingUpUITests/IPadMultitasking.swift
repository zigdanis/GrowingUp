import XCTest

/// The iPad's multitasking mode, which decides whether apps open full screen or in resizable windows.
@MainActor
enum IPadMultitasking {
	/// Chooses a mode, such as `Full Screen Apps` or `Windowed Apps`, in Settings.
	static func choose(_ mode: String) {
		let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
		settings.launch()
		let section = settings.staticTexts["Multitasking & Gestures"].firstMatch
		XCTAssertTrue(section.waitForExistence(timeout: 10))
		section.tap()
		let option = settings.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", mode + ",")).firstMatch
		XCTAssertTrue(option.waitForExistence(timeout: 5))
		option.tap()
		settings.terminate()
	}
}
