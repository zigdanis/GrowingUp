import UIKit

/// The UIKit side of `KeyboardFocusAnchor`: it becomes first responder once it is in a window and offers its commands
/// ahead of the system's own use of their keys, such as the arrows that would scroll.
final class KeyboardFocusAnchorView: UIView {
	var commands: [KeyboardCommand] = []

	override var canBecomeFirstResponder: Bool { true }

	override var keyCommands: [UIKeyCommand]? {
		commands.map { command in
			let keyCommand = UIKeyCommand(
				title: command.title, action: #selector(runCommand(_:)), input: command.input, modifierFlags: command.modifiers)
			keyCommand.wantsPriorityOverSystemBehavior = true
			return keyCommand
		}
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		accessibilityElementsHidden = true
		guard window != nil else { return }
		// On the next turn of the run loop, once a presentation has placed the view, as a window takes only a view it shows.
		DispatchQueue.main.async { [weak self] in
			_ = self?.becomeFirstResponder()
		}
	}

	@objc
	private func runCommand(_ keyCommand: UIKeyCommand) {
		commands.first { $0.input == keyCommand.input && $0.modifiers == keyCommand.modifierFlags }?.action()
	}
}
