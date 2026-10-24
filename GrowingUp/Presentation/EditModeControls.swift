import SwiftUI

/// The edit mode's round controls along the bottom, all the same size: the photo's source menu, the widget and birthday
/// switches, the widget picture's framing and, always last, removal.
struct EditModeControls: View {
	@Bindable var mode: PersonEditModePresenter
	@Binding var photoRequest: PhotoRequest?
	let onFrameWidgetPicture: () -> Void

	var body: some View {
		@Bindable var editor = mode.editor
		HStack(alignment: .top, spacing: 8) {
			PersonPhotoMenu(presenter: editor, photoRequest: $photoRequest) {
				EditModeControlLabel {
					Text("Photo")
				} glyph: {
					Image(systemName: "camera.fill")
				}
			}
			.buttonStyle(.plain)
			.frame(maxWidth: .infinity)
			Toggle(isOn: $editor.isOnWidget) { Text("Widget") }
				.toggleStyle(EditModeToggleStyle(systemImage: "square.grid.2x2.fill"))
				.accessibilityLabel(Text("On widget"))
				.accessibilityIdentifier("editor.pin")
				.frame(maxWidth: .infinity)
			Toggle(isOn: $editor.celebratesBirthdays) { Text("Celebrate") }
				.toggleStyle(EditModeToggleStyle(systemImage: "birthday.cake.fill"))
				.accessibilityLabel(Text("Celebrate birthdays"))
				.accessibilityIdentifier("editor.celebrate")
				.frame(maxWidth: .infinity)
			if mode.showsWidgetPictureButton {
				widgetPictureButton
					.frame(maxWidth: .infinity)
			}
			Button {
				mode.confirmRemoval()
			} label: {
				EditModeControlLabel {
					Text("Remove")
				} glyph: {
					Image(systemName: "trash.fill").foregroundStyle(Color(red: 1, green: 0.42, blue: 0.39))
				}
			}
			.buttonStyle(.plain)
			.accessibilityIdentifier("editor.remove")
			.frame(maxWidth: .infinity)
		}
	}

	/// Shows the current round widget picture and opens its circular crop.
	private var widgetPictureButton: some View {
		Button(action: onFrameWidgetPicture) {
			EditModeControlLabel {
				Text("Circle")
			} glyph: {
				PersonPicture(
					image: mode.editor.widgetImage, loadImage: mode.editor.loadImage, identifier: "widgetPhoto", label: Text("Widget picture"),
					size: EditModeControlLabel<Text, EmptyView>.diameter, onError: { mode.editor.error = SceneError($0) }
				)
				.overlay { Circle().stroke(.white.opacity(0.9), lineWidth: 2) }
			}
		}
		.buttonStyle(.plain)
		.disabled(mode.photo == nil)
		.accessibilityLabel(Text("Widget picture"))
		.accessibilityIdentifier("editor.widgetPhoto.reframe")
	}
}
