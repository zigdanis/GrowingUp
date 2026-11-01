import SwiftUI

/// The calendar for the day of birth or the wheels for its time, as the edit mode's card or popover holds them.
struct EditModePicker: View {
	let mode: PersonEditModePresenter
	let popover: PersonEditPopover

	var body: some View {
		@Bindable var editor = mode.editor
		VStack(alignment: .leading, spacing: 8) {
			switch popover {
			case .date:
				DatePicker("Day of birth", selection: $editor.dayOfBirth, in: ...editor.maximumBirthday, displayedComponents: .date)
					.datePickerStyle(.graphical)
					.labelsHidden()
					.tint(Color(uiColor: .appColor))
					.accessibilityIdentifier("editor.birthDate.picker")
			case .time:
				HStack(alignment: .firstTextBaseline) {
					Text("Time of birth").font(.headline)
					Spacer()
					Text("If known").font(.subheadline).foregroundStyle(.secondary)
				}
				.padding(.horizontal, 8)
				DatePicker("Time of birth", selection: $editor.timeOfBirth, in: ...editor.maximumBirthday, displayedComponents: .hourAndMinute)
					.datePickerStyle(.wheel)
					.labelsHidden()
					.frame(maxWidth: .infinity)
					.accessibilityIdentifier("editor.birthTime.picker")
			}
		}
	}
}
