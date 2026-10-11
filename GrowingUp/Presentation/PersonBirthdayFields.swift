import SwiftUI

struct PersonBirthdayFields: View {
	@Bindable var presenter: PersonEditorPresenter
	let onExpand: () -> Void
	@State private var expandedField: String?

	var body: some View {
		Group {
			Button {
				onExpand()
				withAnimation { expandedField = expandedField == "date" ? nil : "date" }
			} label: {
				HStack {
					Text("Day of birth").foregroundStyle(Color.primary)
					Spacer()
					Text(presenter.birthday, format: .dateTime.day().month().year())
						.foregroundStyle(.tint)
				}
			}
			.accessibilityIdentifier("editor.birthDate")
			if expandedField == "date" {
				DatePicker("Day of birth", selection: $presenter.dayOfBirth, in: ...presenter.maximumBirthday, displayedComponents: .date)
					.datePickerStyle(.wheel)
					.labelsHidden()
					.accessibilityIdentifier("editor.birthDate.picker")
			}
			Button {
				onExpand()
				withAnimation { expandedField = expandedField == "time" ? nil : "time" }
			} label: {
				HStack {
					Text("Time of birth").foregroundStyle(Color.primary)
					Spacer()
					Text(presenter.birthday, format: .dateTime.hour().minute())
						.foregroundStyle(.tint)
				}
			}
			.accessibilityIdentifier("editor.birthTime")
			if expandedField == "time" {
				DatePicker("Time of birth", selection: $presenter.timeOfBirth, in: ...presenter.maximumBirthday, displayedComponents: .hourAndMinute)
					.datePickerStyle(.wheel)
					.labelsHidden()
					.accessibilityIdentifier("editor.birthTime.picker")
			}
		}
	}
}
