import UIKit

/// A hardware keyboard's key and what it does, which `KeyboardFocusAnchor` offers while it is first responder; the title
/// names it in the list a held Command key shows.
struct KeyboardCommand {
	let title: String
	/// The key, such as `UIKeyCommand.inputEscape` or "\r" for Return.
	let input: String
	var modifiers: UIKeyModifierFlags = []
	let action: () -> Void
}
