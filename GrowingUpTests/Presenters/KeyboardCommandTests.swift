import UIKit
import XCTest

@testable import GrowingUp

final class KeyboardCommandTests: XCTestCase {
	func testTheViewersKeysPageEditAndClose() {
		var fired: [String] = []
		let commands = KeyboardCommand.viewer(
			isRightToLeft: false, next: { fired.append("next") }, previous: { fired.append("previous") },
			edit: { fired.append("edit") }, close: { fired.append("close") })
		XCTAssertEqual(commands.map(\.input), [UIKeyCommand.inputRightArrow, UIKeyCommand.inputLeftArrow, "\r", UIKeyCommand.inputEscape])
		XCTAssertTrue(commands.allSatisfy { $0.modifiers.isEmpty }, "Plain keys, no modifier")
		commands.forEach { $0.action() }
		XCTAssertEqual(fired, ["next", "previous", "edit", "close"])
	}

	func testTheViewersArrowsFollowARightToLeftPager() {
		let commands = KeyboardCommand.viewer(isRightToLeft: true, next: {}, previous: {}, edit: {}, close: {})
		XCTAssertEqual(commands[0].input, UIKeyCommand.inputLeftArrow, "Next person")
		XCTAssertEqual(commands[1].input, UIKeyCommand.inputRightArrow, "Previous person")
	}

	func testEditModesKeysCancelAndSave() {
		var fired: [String] = []
		let commands = KeyboardCommand.editMode(escape: { fired.append("escape") }, save: { fired.append("save") })
		XCTAssertEqual(commands.map(\.input), [UIKeyCommand.inputEscape, "\r"])
		XCTAssertEqual(commands.map(\.modifiers), [[], .command], "Escape alone, Command-Return")
		commands.forEach { $0.action() }
		XCTAssertEqual(fired, ["escape", "save"])
	}
}
