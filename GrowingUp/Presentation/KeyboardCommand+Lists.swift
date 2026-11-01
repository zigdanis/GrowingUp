import UIKit

extension KeyboardCommand {
	/// The viewer's keys: the arrows page through people, following a pager that runs the other way in a right-to-left
	/// language; Return edits the shown person and Escape returns to the mosaic.
	static func viewer(
		isRightToLeft: Bool, next: @escaping () -> Void, previous: @escaping () -> Void, edit: @escaping () -> Void,
		close: @escaping () -> Void
	) -> [KeyboardCommand] {
		[
			KeyboardCommand(
				title: String(localized: "Next person"), input: isRightToLeft ? UIKeyCommand.inputLeftArrow : UIKeyCommand.inputRightArrow,
				action: next),
			KeyboardCommand(
				title: String(localized: "Previous person"),
				input: isRightToLeft ? UIKeyCommand.inputRightArrow : UIKeyCommand.inputLeftArrow, action: previous),
			KeyboardCommand(title: String(localized: "Edit"), input: "\r", action: edit),
			KeyboardCommand(title: String(localized: "All people"), input: UIKeyCommand.inputEscape, action: close)
		]
	}

	/// Edit mode's keys while the name field has no keyboard: Escape closes an open picker or else cancels, and
	/// Command-Return saves.
	static func editMode(escape: @escaping () -> Void, save: @escaping () -> Void) -> [KeyboardCommand] {
		[
			KeyboardCommand(title: String(localized: "Cancel"), input: UIKeyCommand.inputEscape, action: escape),
			KeyboardCommand(title: String(localized: "Done"), input: "\r", modifiers: .command, action: save)
		]
	}
}
