import SwiftUI

/// The next birthday at the bottom of a person page, straight on the photo's darkened bottom.
struct BirthdayLine: View {
	let birthdayText: String
	/// Whether the pager shows this page. The paging scroll view keeps neighbouring pages loaded, so only the shown
	/// page carries the identifiers UI tests look up.
	var isShown = true

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Image(systemName: "birthday.cake.fill")
				.accessibilityHidden(true)
			Text(birthdayText)
				.monospacedDigit()
				.accessibilityIdentifier(isShown ? "birthday.countdown" : "")
		}
		.font(.headline)
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.35), radius: 8, y: 2)
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
