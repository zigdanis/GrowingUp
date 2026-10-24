import SwiftUI

/// The calendar or the time wheels in a card centred on the screen over a dim layer; a tap outside the card closes it.
struct EditModePopoverCard: View {
	let mode: PersonEditModePresenter
	let popover: PersonEditPopover
	/// The widest the card gets, padding included; it must fit between the safe-area sides, as the time wheels cannot shrink.
	let maxWidth: CGFloat
	/// The window's safe area; the card centres between its sides, clear of iPhone Duo's side status bar, like the controls.
	let safeAreaInsets: EdgeInsets

	var body: some View {
		ZStack {
			Color.black.opacity(0.35)
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture { mode.dismissPopover() }
				.accessibilityHidden(true)
			card
				.padding(24)
				.frame(maxWidth: maxWidth)
				.padding(.leading, safeAreaInsets.leading)
				.padding(.trailing, safeAreaInsets.trailing)
		}
	}

	private var card: some View {
		@Bindable var editor = mode.editor
		return VStack(alignment: .leading, spacing: 8) {
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
		.padding(12)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
		.shadow(color: .black.opacity(0.5), radius: 30, y: 10)
		.accessibilityElement(children: .contain)
		.accessibilityAddTraits(.isModal)
		.accessibilityAction(.escape) { mode.dismissPopover() }
		.accessibilityIdentifier("editor.popover")
	}
}
