import Core
import SwiftUI

/// The editor's photo-first header: the main photo edge to edge, with its source menu on top.
struct PersonEditorHero: View {
	let presenter: PersonEditorPresenter
	@Binding var photoRequest: PhotoRequest?
	@Environment(\.dynamicTypeSize)
	private var dynamicTypeSize

	var body: some View {
		PersonImageLoader(
			image: presenter.appImage, loadImage: presenter.loadImage, onError: { presenter.error = SceneError($0) },
			content: { loaded in
				Rectangle()
					.fill(.quaternary)
					.containerRelativeFrame(.vertical) { length, _ in height(forContainer: length) }
					.overlay {
						if let loaded {
							Image(uiImage: loaded)
								.resizable()
								.scaledToFill()
								.accessibilityLabel(Text("Selected photo"))
								.accessibilityIdentifier("editor.appPhoto.loaded")
						} else if presenter.appImage != nil {
							ProgressView()
						}
					}
					.clipped()
					.overlay {
						// Keeps the glass control legible on bright photos.
						if loaded != nil {
							LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
								.allowsHitTesting(false)
						}
					}
					.overlay(alignment: .bottomTrailing) {
						if presenter.appImage == nil { addPhotoMenu } else { changePhotoMenu }
					}
			})
	}

	/// About 40% of the sheet, less under accessibility text sizes so the fields stay reachable.
	private func height(forContainer length: CGFloat) -> CGFloat {
		let fraction: CGFloat = dynamicTypeSize.isAccessibilitySize ? 0.28 : 0.4
		return min(max(length * fraction, 180), 420)
	}

	private var addPhotoMenu: some View {
		PersonPhotoMenu(presenter: presenter, photoRequest: $photoRequest) {
			VStack(spacing: 10) {
				Image(systemName: "photo.badge.plus")
					.font(.largeTitle)
				Text("Add a photo")
					.font(.headline)
			}
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private var changePhotoMenu: some View {
		PersonPhotoMenu(presenter: presenter, photoRequest: $photoRequest) {
			Label("Change photo", systemImage: "photo.on.rectangle")
				.font(.subheadline.weight(.semibold))
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
		}
		.modifier(GlassButtonChrome(prominent: false, shape: .capsule))
		.padding(16)
	}
}
