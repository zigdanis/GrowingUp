import SwiftUI

/// One of the edit mode's five round controls: a glass circle with its glyph and the title underneath.
///
/// A switched-on control turns into a white circle with a dark glyph and a green checkmark badge, so its state reads by
/// shape as well as colour.
///
/// The glyph keeps to its fixed circle, and the title grows with the text size up to a limit that keeps three controls
/// side by side; beyond it, a long press shows the control in the large content viewer, as a tab bar does.
struct EditModeControlLabel<Title: View, Glyph: View>: View {
	static var diameter: CGFloat { 56 }
	var isOn = false
	@ViewBuilder let title: () -> Title
	@ViewBuilder let glyph: () -> Glyph

	var body: some View {
		VStack(spacing: 6) {
			glyph()
				.font(.title2)
				.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
				.foregroundStyle(isOn ? AnyShapeStyle(.black) : AnyShapeStyle(.white))
				.frame(width: Self.diameter, height: Self.diameter)
				.background { circle }
				.overlay(alignment: .bottomTrailing) {
					if isOn { badge }
				}
			title()
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.white)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
				.dynamicTypeSize(...DynamicTypeSize.accessibility2)
				.shadow(color: .black.opacity(0.5), radius: 4, y: 1)
		}
		.contentShape(Rectangle())
		.accessibilityShowsLargeContentViewer {
			glyph()
			title()
		}
	}

	@ViewBuilder private var circle: some View {
		if isOn {
			Circle().fill(.white)
		} else {
			EditModeGlass(shape: Circle())
		}
	}

	private var badge: some View {
		Image(systemName: "checkmark")
			.font(.system(size: 11, weight: .heavy))
			.foregroundStyle(.white)
			.frame(width: 20, height: 20)
			.background(Circle().fill(.green))
			.overlay { Circle().stroke(.black.opacity(0.25), lineWidth: 1) }
			.offset(x: 2, y: 2)
			.accessibilityHidden(true)
	}
}
