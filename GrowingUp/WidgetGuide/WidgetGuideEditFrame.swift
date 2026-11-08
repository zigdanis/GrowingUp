import SwiftUI

/// Step 2: the icons jiggle, "Edit" is tapped, and its menu offers "Add Widget".
struct WidgetGuideEditFrame: View {
	let isAnimated: Bool

	var body: some View {
		WidgetGuideCanvas {
			PlaceholderIconGrid(count: 12, isEditing: true, isAnimated: isAnimated)
				.frame(width: 297)
				.offset(x: 28, y: 70)
			pill("Edit", isHighlighted: true)
				.offset(x: 14, y: 14)
			pill("Done", isHighlighted: false)
				.frame(width: 353 - 28, alignment: .trailing)
				.offset(x: 14, y: 14)
			if isAnimated {
				// The menu opens under "Edit" and stays a while before it plays again.
				PhaseAnimator([false, true]) { isOpen in
					menu.opacity(isOpen ? 1 : 0).scaleEffect(isOpen ? 1 : 0.6, anchor: .topLeading)
				} animation: { isOpen in
					isOpen ? .spring(duration: 0.4).delay(0.3) : .easeOut(duration: 0.2).delay(1.8)
				}
				.offset(x: 14, y: 56)
			} else {
				menu.offset(x: 14, y: 56)
			}
		}
	}

	private func pill(_ title: LocalizedStringKey, isHighlighted: Bool) -> some View {
		Text(title)
			.font(.system(size: 15, weight: .semibold))
			.foregroundStyle(isHighlighted ? Color(white: 0.07) : .white)
			.padding(.horizontal, 16)
			.frame(height: 34)
			.background(isHighlighted ? Color.white.opacity(0.95) : Color.white.opacity(0.22), in: .capsule)
	}

	private var menu: some View {
		VStack(spacing: 0) {
			menuItem("Add Widget", systemImage: "plus.square.on.square", isHighlighted: true)
			Divider().overlay(Color.black.opacity(0.1))
			menuItem("Customize", systemImage: "paintbrush", isHighlighted: false)
		}
		.frame(width: 230)
		.background(Color(white: 0.96, opacity: 0.94))
		.clipShape(.rect(cornerRadius: 16, style: .continuous))
		.shadow(color: .black.opacity(0.35), radius: 15, y: 12)
	}

	private func menuItem(_ title: LocalizedStringKey, systemImage: String, isHighlighted: Bool) -> some View {
		HStack {
			Text(title)
				.fontWeight(isHighlighted ? .semibold : .regular)
			Spacer()
			Image(systemName: systemImage)
		}
		.font(.system(size: 16))
		.foregroundStyle(Color(white: 0.07))
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.background(isHighlighted ? Color(uiColor: .appColor).opacity(0.22) : .clear)
	}
}
