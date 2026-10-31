import SwiftUI

/// The edit mode's round controls along the bottom, all the same size: the photo's source menu, the widget and birthday
/// switches, the widget picture's framing and, always last, removal. A new person has no removal, and no widget picture
/// until they have a photo.
///
/// They share one row; when their titles do not fit, as at accessibility text sizes, the actions wrap under the photo
/// and the switches.
struct EditModeControls: View {
	let mode: PersonEditModePresenter
	@Binding var photoRequest: PhotoRequest?
	let onFrameWidgetPicture: () -> Void

	var body: some View {
		ViewThatFits(in: .horizontal) {
			HStack(alignment: .top, spacing: 8) {
				settings
				actions
			}
			Grid(horizontalSpacing: 8, verticalSpacing: 16) {
				GridRow(alignment: .top) { settings }
				if mode.showsWidgetPictureButton || mode.showsRemoveButton {
					GridRow(alignment: .top) { actions }
				}
			}
		}
	}

	/// The photo and the two switches, which every person has.
	@ViewBuilder private var settings: some View {
		@Bindable var editor = mode.editor
		photoMenu
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
	}

	/// The widget picture's framing and removal, when the person has them.
	@ViewBuilder private var actions: some View {
		if mode.showsWidgetPictureButton {
			widgetPictureButton
				.frame(maxWidth: .infinity)
		}
		if mode.showsRemoveButton {
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
			.accessibilityLabel(Text("Remove"))
			.accessibilityIdentifier("editor.remove")
			.modifier(RemovalConfirmation(mode: mode, isOnButton: true))
			.frame(maxWidth: .infinity)
		}
	}

	/// The photo's source menu over its round control, which it covers exactly, title included. The control lies under the
	/// menu rather than serving as its label: a menu draws glass in its label around the whole label, which centred the
	/// circle on the title too and pushed it below the glyph.
	private var photoMenu: some View {
		EditModeControlLabel {
			Text("Photo")
		} glyph: {
			Image(systemName: "camera.fill")
		}
		.accessibilityHidden(true)
		.overlay {
			PersonPhotoMenu(presenter: mode.editor, photoRequest: $photoRequest) {
				Color.clear.contentShape(.rect)
			}
			.buttonStyle(.plain)
			.accessibilityShowsLargeContentViewer {
				Image(systemName: "camera.fill")
				Text("Photo")
			}
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
