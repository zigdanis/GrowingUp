import SwiftUI

/// A round edit-mode switch: glass while off, white with a checkmark badge while on. Like `ChipToggleStyle`, it reports
/// its state as selected, with a "1"/"0" value like a switch.
struct EditModeToggleStyle: ToggleStyle {
	let systemImage: String

	func makeBody(configuration: Configuration) -> some View {
		Button {
			configuration.isOn.toggle()
		} label: {
			EditModeControlLabel(isOn: configuration.isOn) {
				configuration.label
			} glyph: {
				Image(systemName: systemImage)
			}
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(configuration.isOn ? .isSelected : [])
		.accessibilityValue(Text(verbatim: configuration.isOn ? "1" : "0"))
	}
}
