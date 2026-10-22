import SwiftUI

/// The glass card at the bottom of a person page: the next birthday and the button that opens the editor.
struct BirthdayCard: View {
	let birthdayText: String
	let onEdit: () -> Void
	/// Whether the pager shows this page. The paging scroll view keeps neighbouring pages loaded, so only the shown
	/// page carries the identifiers UI tests look up.
	var isShown = true

	var body: some View {
		ViewThatFits(in: .horizontal) {
			HStack(spacing: 12) {
				countdown
				Spacer(minLength: 8)
				editButton
			}
			VStack(alignment: .leading, spacing: 12) {
				countdown
				editButton
			}
		}
		.padding(.leading, 20)
		.padding(.trailing, 12)
		.padding(.vertical, 12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.modifier(GlassCardChrome(cornerRadius: 28))
	}

	private var countdown: some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Image(systemName: "birthday.cake.fill")
				.accessibilityHidden(true)
			Text(birthdayText)
				.monospacedDigit()
				.accessibilityIdentifier(isShown ? "birthday.countdown" : "")
		}
		.font(.headline)
		.foregroundStyle(.white)
	}

	private var editButton: some View {
		Button(action: onEdit) {
			Label("Edit", systemImage: "pencil")
				.font(.headline)
				.foregroundStyle(.white)
		}
		.modifier(GlassCapsuleButtonChrome(prominent: false))
		.tint(.white)
		.accessibilityIdentifier(isShown ? "person.edit" : "")
	}
}
