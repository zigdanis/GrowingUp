import SwiftUI

/// A circular avatar of the people strip, ringed and slightly enlarged while its page is shown.
struct AvatarCircle<Content: View>: View {
	let isSelected: Bool
	@ViewBuilder let content: Content

	var body: some View {
		content
			.frame(width: 36, height: 36)
			.clipShape(Circle())
			.overlay {
				Circle().strokeBorder(Color.primary.opacity(isSelected ? 1 : 0.35), lineWidth: isSelected ? 2 : 1)
			}
			.scaleEffect(isSelected ? 1.15 : 1)
			.shadow(color: .black.opacity(0.3), radius: 3, y: 1)
			.frame(width: 44, height: 44)
			.contentShape(Circle())
			.animation(.snappy, value: isSelected)
	}
}
