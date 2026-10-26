import SwiftUI

/// The empty mosaic's short invitation; the floating "Add" button below it is the one way in, as it stays later.
///
/// It sits centred in the space above the button; when the largest text sizes leave it no room, as on an iPhone Duo, it
/// scrolls rather than truncating.
struct PeopleInvitation: View {
	var body: some View {
		ViewThatFits(in: .vertical) {
			invitation
			ScrollView { invitation }
				.scrollBounceBehavior(.basedOnSize)
		}
	}

	private var invitation: some View {
		VStack(spacing: 12) {
			Text("Who is growing up?")
				.font(.title.bold())
				.accessibilityAddTraits(.isHeader)
				.accessibilityIdentifier("people.invitation.title")
			Text("Add someone you love and watch their age count up, live to the second.")
				.font(.body)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier("people.invitation.message")
		}
		.multilineTextAlignment(.center)
		.padding(32)
		// Wider than any iPhone, such as an iPhone Duo, the invitation stays a readable column.
		.frame(maxWidth: 440)
		.frame(maxWidth: .infinity)
	}
}
