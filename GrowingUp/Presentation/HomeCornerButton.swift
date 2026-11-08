import SwiftUI

/// The home screen's one corner control, at the top trailing edge above the mosaic: while store recovery keeps earlier
/// data aside, a quiet glass capsule that opens it. Tiles start below it, so it never covers a face.
struct HomeCornerButton: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Label("Earlier data preserved", systemImage: "archivebox")
				.font(.subheadline.weight(.semibold))
		}
		.modifier(GlassCapsuleButtonChrome(prominent: false))
		.controlSize(.regular)
		.lineLimit(1)
		.dynamicTypeSize(...DynamicTypeSize.accessibility1)
		.accessibilityShowsLargeContentViewer()
		.accessibilityHint("Shows what happened and lets you export a copy")
		.accessibilityIdentifier("people.preservedData")
	}
}
