import SwiftUI

/// The mosaic's floating "Add" capsule in the app colour: the one control on the home screen, so it may be bright.
struct AddPersonButton: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Label("Add person", systemImage: "plus")
				.font(.headline)
				// About half an iPhone's width, the size of a primary action without crowding the tiles.
				.frame(minWidth: 160, minHeight: 34)
		}
		.modifier(GlassCapsuleButtonChrome(prominent: true))
		.controlSize(.large)
		.shadow(color: Color(uiColor: .appColor).opacity(0.4), radius: 12, y: 8)
		.accessibilityIdentifier("person.add")
	}
}
