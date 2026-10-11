import SwiftUI

struct PersonPhotoMenu: View {
	@Bindable var presenter: PersonEditorPresenter
	let isWidget: Bool
	@Binding var photoRequest: PhotoRequest?

	var body: some View {
		Menu {
			Button("Photos", systemImage: "photo") {
				photoRequest = PhotoRequest(isWidget: isWidget, source: .photos)
			}
			.accessibilityIdentifier("photo.source.photos")
			Button("Camera", systemImage: "camera") {
				photoRequest = PhotoRequest(isWidget: isWidget, source: .camera)
			}
			if (isWidget ? presenter.widgetImage : presenter.appImage) != nil {
				Button("Remove", systemImage: "trash", role: .destructive) {
					if isWidget { presenter.widgetImage = nil } else { presenter.appImage = nil }
				}
				.accessibilityIdentifier("photo.source.remove")
			}
		} label: {
			VStack(spacing: 12) {
				PersonPicture(
					image: isWidget ? presenter.widgetImage : presenter.appImage, loadImage: presenter.loadImage,
					identifier: isWidget ? "widgetPhoto" : "appPhoto", onError: { presenter.error = SceneError($0) })
				Text(isWidget ? LocalizedStringKey("widget pic") : LocalizedStringKey("main pic"))
			}
			.frame(maxWidth: .infinity)
		}
		.accessibilityLabel(isWidget ? Text("Change widget picture") : Text("Change app picture"))
		.accessibilityIdentifier(isWidget ? "editor.widgetPhoto" : "editor.appPhoto")
	}
}
