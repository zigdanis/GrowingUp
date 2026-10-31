import SwiftUI

/// An invisible view that takes the keyboard's first responder where it appears, so a hardware keyboard's shortcuts
/// reach the full-screen cover it sits in: with no first responder inside the cover, the keys go to the screen beneath.
///
/// It gives way to a text field that takes the keyboard, and should be left out while one has it.
struct KeyboardFocusAnchor: UIViewRepresentable {
	func makeUIView(context: Context) -> KeyboardFocusAnchorView {
		KeyboardFocusAnchorView()
	}

	func updateUIView(_ uiView: KeyboardFocusAnchorView, context: Context) {}
}
