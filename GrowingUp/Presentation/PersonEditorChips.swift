import SwiftUI

/// The widget and birthday chips under the "Born" row, with the widget picture and its "Reframe" action.
/// The row wraps onto more lines when the chips do not fit, for example at accessibility text sizes.
struct PersonEditorChips: View {
	@Bindable var presenter: PersonEditorPresenter
	let onReframe: () -> Void
	@ScaledMetric(relativeTo: .subheadline)
	private var pictureSize: CGFloat = 32

	var body: some View {
		ViewThatFits(in: .horizontal) {
			HStack(spacing: 10) {
				widgetChip
				widgetPicture
				celebrateChip
			}
			VStack(alignment: .leading, spacing: 12) {
				ViewThatFits(in: .horizontal) {
					HStack(spacing: 10) {
						widgetChip
						widgetPicture
					}
					VStack(alignment: .leading, spacing: 12) {
						widgetChip
						widgetPicture
					}
				}
				celebrateChip
			}
		}
	}

	private var widgetChip: some View {
		Toggle(isOn: $presenter.isOnWidget) {
			Label("On widget", systemImage: "square.grid.2x2")
		}
		.toggleStyle(ChipToggleStyle())
		.accessibilityIdentifier("editor.pin")
	}

	private var celebrateChip: some View {
		Toggle(isOn: $presenter.celebratesBirthdays) {
			Label("Celebrate birthdays", systemImage: "birthday.cake")
		}
		.toggleStyle(ChipToggleStyle())
		.accessibilityIdentifier("editor.celebrate")
	}

	private var widgetPicture: some View {
		HStack(spacing: 8) {
			PersonPicture(
				image: presenter.widgetImage, loadImage: presenter.loadImage, identifier: "widgetPhoto", label: Text("Widget picture"),
				size: pictureSize, onError: { presenter.error = SceneError($0) })
			Button("Reframe", systemImage: "crop", action: onReframe)
				.buttonStyle(.bordered)
				.buttonBorderShape(.capsule)
				.controlSize(.small)
				.disabled(presenter.appImage == nil)
				.accessibilityIdentifier("editor.widgetPhoto.reframe")
		}
	}
}
