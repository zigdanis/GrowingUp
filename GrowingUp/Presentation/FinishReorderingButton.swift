import SwiftUI

/// "Done" in the floating "Add" button's place while the mosaic is reordering, in the same app-coloured capsule.
struct FinishReorderingButton: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Label("Done", systemImage: "checkmark")
				.font(.headline)
				.frame(minWidth: 160, minHeight: 34)
		}
		.modifier(GlassCapsuleButtonChrome(prominent: true))
		.controlSize(.large)
		.shadow(color: Color(uiColor: .appColor).opacity(0.4), radius: 12, y: 8)
		.accessibilityIdentifier("people.reorder.done")
	}
}
