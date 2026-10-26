import SwiftUI

/// The mosaic's floating capsule in the app colour: the one control on the home screen, so it may be bright. It offers
/// "Add" and, while the mosaic is reordering, "Done" in its place.
///
/// It keeps to one line, growing up to a size that leaves the mosaic room; beyond it, a long press shows it in the large
/// content viewer, like the edit mode's Cancel and Done.
struct FloatingCapsuleButton: View {
	let title: LocalizedStringKey
	let systemImage: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Label(title, systemImage: systemImage)
				.font(.headline)
				// About half an iPhone's width, the size of a primary action without crowding the tiles.
				.frame(minWidth: 160, minHeight: 34)
		}
		.modifier(GlassCapsuleButtonChrome(prominent: true))
		.controlSize(.large)
		.shadow(color: Color(uiColor: .appColor).opacity(0.4), radius: 12, y: 8)
		.lineLimit(1)
		.dynamicTypeSize(...DynamicTypeSize.accessibility1)
		.accessibilityShowsLargeContentViewer()
	}
}
