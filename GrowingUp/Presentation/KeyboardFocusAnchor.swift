import SwiftUI

/// An invisible view that takes the keyboard's first responder where it appears and answers `commands`: inside a
/// full-screen cover, with no first responder of its own, a hardware keyboard's keys and SwiftUI's shortcuts reach only
/// the screen beneath.
///
/// It gives way to a text field that takes the keyboard, and should be left out while one has it.
struct KeyboardFocusAnchor: UIViewRepresentable {
	let commands: [KeyboardCommand]

	func makeUIView(context: Context) -> KeyboardFocusAnchorView {
		let view = KeyboardFocusAnchorView()
		view.commands = commands
		return view
	}

	func updateUIView(_ uiView: KeyboardFocusAnchorView, context: Context) {
		uiView.commands = commands
	}
}
