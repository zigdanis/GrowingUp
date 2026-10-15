import SwiftUI

/// The "Born" row and, once expanded, its date wheel, "Time of birth" toggle and time wheel.
struct PersonBirthdayFields: View {
	private static let pickersID = "editor.birthday.pickers"
	@Bindable var presenter: PersonEditorPresenter
	let proxy: ScrollViewProxy
	let onExpand: () -> Void
	@State private var isExpanded = false
	@Environment(\.dynamicTypeSize)
	private var dynamicTypeSize

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			bornRow
			if isExpanded {
				pickers.id(Self.pickersID)
			}
		}
		.onChange(of: isExpanded) { _, expanded in
			if expanded { reveal() }
		}
		.onChange(of: presenter.hasBirthTime) { _, hasTime in
			if hasTime { reveal() }
		}
	}

	private var bornRow: some View {
		Button {
			onExpand()
			withAnimation { isExpanded.toggle() }
		} label: {
			rowLayout {
				Text("Born")
					.foregroundStyle(.primary)
				Text(bornValue)
					.foregroundStyle(.tint)
					.multilineTextAlignment(isStacked ? .leading : .trailing)
					.frame(maxWidth: .infinity, alignment: isStacked ? .leading : .trailing)
			}
			.padding(.vertical, 12)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityIdentifier("editor.birthDate")
	}

	private var pickers: some View {
		VStack(alignment: .leading, spacing: 0) {
			DatePicker("Day of birth", selection: $presenter.dayOfBirth, in: ...presenter.maximumBirthday, displayedComponents: .date)
				.datePickerStyle(.wheel)
				.labelsHidden()
				.frame(maxWidth: .infinity)
				.accessibilityIdentifier("editor.birthDate.picker")
			Toggle("Time of birth", isOn: $presenter.hasBirthTime.animation())
				.padding(.vertical, 8)
				.accessibilityIdentifier("editor.birthTime")
			if presenter.hasBirthTime {
				DatePicker("Time of birth", selection: $presenter.timeOfBirth, in: ...presenter.maximumBirthday, displayedComponents: .hourAndMinute)
					.datePickerStyle(.wheel)
					.labelsHidden()
					.frame(maxWidth: .infinity)
					.accessibilityIdentifier("editor.birthTime.picker")
			}
		}
	}

	/// Accessibility text sizes stack the label above the value so a long date can wrap.
	private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

	private var rowLayout: AnyLayout {
		if isStacked {
			return AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
		}
		return AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 16))
	}

	/// The formatted birthday, followed by the time when it is known, e.g. "March 12, 2021 · 2:30 PM".
	private var bornValue: String {
		let day = presenter.birthday.formatted(.dateTime.day().month(.wide).year())
		guard presenter.hasBirthTime else { return day }
		return "\(day) · \(presenter.birthday.formatted(.dateTime.hour().minute()))"
	}

	/// Scrolls the expanded pickers into view so their wheels are not left below the fold.
	private func reveal() {
		withAnimation { proxy.scrollTo(Self.pickersID, anchor: .bottom) }
	}
}
