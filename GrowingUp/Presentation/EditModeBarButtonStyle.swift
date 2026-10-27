import SwiftUI

/// Cancel and Done above the edit mode's fields: one compact capsule, 44 pt tall at the default text size, in glass for
/// Cancel and white for the prominent Done. Both grow alike with the text, so they always match. A pressed button dims
/// and a disabled one fades, as a plain button does.
struct EditModeBarButtonStyle: ButtonStyle {
	let isProminent: Bool
	@Environment(\.isEnabled)
	private var isEnabled

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.headline)
			.foregroundStyle(isProminent ? Color.black : Color.white)
			.padding(.horizontal, 18)
			.frame(minHeight: 44)
			.background {
				if isProminent {
					Capsule().fill(.white)
				} else {
					EditModeGlass(shape: Capsule())
				}
			}
			.contentShape(Capsule())
			.opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
	}
}
