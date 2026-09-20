import SwiftUI

struct PhotoPreviewControls: View {
	let onBack: () -> Void
	let onAllPhotos: () -> Void

	var body: some View {
		if #available(iOS 26.0, *) {
			GlassEffectContainer {
				HStack {
					Button(action: onBack) {
						Image(systemName: "chevron.left").foregroundStyle(.white)
							.shadow(color: .black.opacity(0.6), radius: 2).frame(width: 44, height: 44)
					}
					.buttonStyle(.plain).glassEffect(.clear.interactive()).accessibilityLabel(Text("Back"))
					Spacer()
					Button(action: onAllPhotos) {
						Text("All Photos").font(.headline).foregroundStyle(.white)
							.shadow(color: .black.opacity(0.6), radius: 2).padding(.horizontal, 20).frame(height: 44)
					}
					.buttonStyle(.plain).glassEffect(.clear.interactive())
				}
				.padding(.horizontal, 16).padding(.vertical, 8)
			}
		} else {
			controls.buttonStyle(.borderedProminent).tint(Color(.systemBackground))
		}
	}

	private var controls: some View {
		HStack {
			Button(action: onBack) { Image(systemName: "chevron.left").foregroundStyle(Color.primary) }
				.accessibilityLabel(Text("Back"))
			Spacer()
			Button(action: onAllPhotos) { Text("All Photos").font(.headline).foregroundStyle(Color.primary) }
		}
		.controlSize(.large).padding(.horizontal, 16).padding(.vertical, 8)
	}
}
