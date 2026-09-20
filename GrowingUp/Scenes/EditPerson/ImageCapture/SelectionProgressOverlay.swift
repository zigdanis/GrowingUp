import SwiftUI

/// Blocking progress UI while a full-resolution image loads.
struct SelectionProgressOverlay: View {
	let progress: Double
	let onCancel: () -> Void

	var body: some View {
		VStack(spacing: 16) {
			if progress > 0 && progress < 1 {
				ProgressView(value: progress).progressViewStyle(.linear).frame(width: 160)
			} else {
				ProgressView()
			}
			Button("Cancel", action: onCancel).font(.subheadline.weight(.semibold))
		}
		.padding(24)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
	}
}
