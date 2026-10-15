import SwiftUI

/// A capsule chip that is tinted while on. It reports its state as selected, with a "1"/"0" value like a switch.
struct ChipToggleStyle: ToggleStyle {
	func makeBody(configuration: Configuration) -> some View {
		Button {
			configuration.isOn.toggle()
		} label: {
			configuration.label
				.font(.subheadline.weight(.semibold))
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
				.foregroundStyle(configuration.isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
				.background {
					if configuration.isOn {
						Capsule().fill(.tint)
					} else {
						Capsule().fill(.quaternary)
					}
				}
				.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(configuration.isOn ? .isSelected : [])
		.accessibilityValue(Text(verbatim: configuration.isOn ? "1" : "0"))
	}
}
