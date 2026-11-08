import SwiftUI

/// The home screen's one corner control, at the top trailing edge above the mosaic: a quiet glass circle that opens
/// Settings, or while store recovery keeps earlier data aside, a glass capsule that says so and opens that data there.
/// Tiles start below it, so it never covers a face.
struct HomeCornerButton: View {
	/// Whether store recovery keeps earlier data aside, which the capsule announces.
	let showsPreservedData: Bool
	let action: () -> Void

	var body: some View {
		if showsPreservedData {
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
		} else {
			Button(action: action) {
				Label("Settings", systemImage: "gearshape")
					.labelStyle(.iconOnly)
					.font(.subheadline.weight(.semibold))
					.frame(minWidth: 20, minHeight: 20)
			}
			// Set closest to the button, the circle wins over the chrome's capsule.
			.buttonBorderShape(.circle)
			.modifier(GlassCapsuleButtonChrome(prominent: false))
			.controlSize(.regular)
			.dynamicTypeSize(...DynamicTypeSize.accessibility1)
			.accessibilityShowsLargeContentViewer()
			.accessibilityIdentifier("people.settings")
		}
	}
}
