import SwiftUI

/// The edit mode's fields in the top third, where the keyboard never covers them: the name, the date and time capsules
/// and the age they give.
struct EditModeFields: View {
	let mode: PersonEditModePresenter
	var isNameFocused: FocusState<Bool>.Binding

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			nameField
			// The capsules share a row; at accessibility text sizes the time moves under the date, and then the cake gives way,
			// rather than truncating either.
			ViewThatFits(in: .horizontal) {
				HStack(spacing: 8) {
					cake
					dateCapsule
					timeCapsule
				}
				VStack(alignment: .leading, spacing: 8) {
					HStack(spacing: 8) {
						cake
						dateCapsule
					}
					timeCapsule
				}
				VStack(alignment: .leading, spacing: 8) {
					dateCapsule
					timeCapsule
				}
			}
			.dynamicTypeSize(...DynamicTypeSize.accessibility2)
			Text(mode.ageText)
				.font(.subheadline.weight(.medium))
				.monospacedDigit()
				.opacity(0.85)
				.dynamicTypeSize(...DynamicTypeSize.accessibility2)
				.accessibilityIdentifier("editor.age")
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.35), radius: 8, y: 2)
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var nameField: some View {
		@Bindable var editor = mode.editor
		return TextField("Name", text: $editor.name, prompt: Text("Name").foregroundStyle(.white.opacity(0.5)))
			.font(.largeTitle.bold())
			.textFieldStyle(.plain)
			.textContentType(.name)
			.textInputAutocapitalization(.words)
			// Return only hides the keyboard; the white Done in the corner saves.
			.submitLabel(.done)
			.focused(isNameFocused)
			.padding(.bottom, 4)
			.overlay(alignment: .bottom) {
				Rectangle().fill(.white.opacity(0.9)).frame(height: 2)
			}
			.accessibilityIdentifier("editor.name")
	}

	private var cake: some View {
		Image(systemName: "birthday.cake.fill")
			.font(.headline)
			.opacity(0.8)
			.accessibilityHidden(true)
	}

	private var dateCapsule: some View {
		capsule(mode.dateText, popover: .date, label: Text("Day of birth"), identifier: "editor.birthDate")
	}

	private var timeCapsule: some View {
		capsule(mode.timeText, popover: .time, label: Text("Time of birth"), identifier: "editor.birthTime")
	}

	private func capsule(_ text: String, popover: PersonEditPopover, label: Text, identifier: String) -> some View {
		Button {
			isNameFocused.wrappedValue = false
			mode.show(popover)
		} label: {
			Text(text)
				.font(.headline)
				.monospacedDigit()
				.lineLimit(1)
				.minimumScaleFactor(0.7)
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
		}
		.modifier(GlassButtonChrome(prominent: false, shape: .capsule))
		.accessibilityLabel(label)
		.accessibilityValue(Text(text))
		.accessibilityIdentifier(identifier)
	}
}
