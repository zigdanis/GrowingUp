import SwiftUI

/// A round edit-mode switch: glass while off, white with a checkmark badge while on. It reports itself as a toggle in
/// its state, selected or not, with a "1"/"0" value like a switch, so VoiceOver reads it as on or off.
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
		.accessibilityAddTraits(configuration.isOn ? [.isToggle, .isSelected] : .isToggle)
		.accessibilityValue(Text(verbatim: configuration.isOn ? "1" : "0"))
	}
}
