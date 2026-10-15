import SwiftUI

/// The main photo's source menu: Photos, Camera and, when there is a photo, Remove.
struct PersonPhotoMenu<MenuLabel: View>: View {
	let presenter: PersonEditorPresenter
	@Binding var photoRequest: PhotoRequest?
	@ViewBuilder let label: () -> MenuLabel

	var body: some View {
		Menu {
			Button("Photos", systemImage: "photo") { photoRequest = PhotoRequest(source: .photos) }
				.accessibilityIdentifier("photo.source.photos")
			Button("Camera", systemImage: "camera") { photoRequest = PhotoRequest(source: .camera) }
			if presenter.appImage != nil {
				Button("Remove", systemImage: "trash", role: .destructive) { presenter.removeMainPhoto() }
					.accessibilityIdentifier("photo.source.remove")
			}
		} label: {
			label()
		}
		.accessibilityLabel(presenter.appImage == nil ? Text("Add a photo") : Text("Change photo"))
		.accessibilityIdentifier("editor.appPhoto")
	}
}
