import SwiftUI

struct ImageSourceSelectionView: View {
	let onCamera: () -> Void
	let onPhotos: () -> Void
	let onCancel: () -> Void

	var body: some View {
		VStack(spacing: 16) {
			Spacer()
			Button("Camera", systemImage: "camera", action: onCamera)
			Button("Photos", systemImage: "photo", action: onPhotos)
			Spacer()
			Button("Cancel", role: .cancel, action: onCancel)
		}
		.buttonStyle(.bordered).controlSize(.large).padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.secondarySystemBackground))
	}
}
