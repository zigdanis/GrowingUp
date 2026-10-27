import SwiftUI

/// The main photo's source menu: Photos, Camera and, when there is a photo, Remove. A widget picture alone, which the
/// person's page shows in place of a main photo, counts as their photo here too.
struct PersonPhotoMenu<MenuLabel: View>: View {
	let presenter: PersonEditorPresenter
	@Binding var photoRequest: PhotoRequest?
	@ViewBuilder let label: () -> MenuLabel

	var body: some View {
		Menu {
			Button("Photos", systemImage: "photo") { photoRequest = PhotoRequest(source: .photos) }
				.accessibilityIdentifier("photo.source.photos")
			Button("Camera", systemImage: "camera") { photoRequest = PhotoRequest(source: .camera) }
				.accessibilityIdentifier("photo.source.camera")
			if hasPhoto {
				Button("Remove", systemImage: "trash", role: .destructive) { presenter.removeMainPhoto() }
					.accessibilityIdentifier("photo.source.remove")
			}
		} label: {
			label()
		}
		.accessibilityLabel(hasPhoto ? Text("Change photo") : Text("Add a photo"))
		.accessibilityIdentifier("editor.appPhoto")
	}

	private var hasPhoto: Bool { presenter.appImage != nil || presenter.widgetImage != nil }
}
