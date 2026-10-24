import SwiftUI

/// The empty mosaic's short invitation; the floating "Add" button below it is the one way in, as it stays later.
struct PeopleInvitation: View {
	var body: some View {
		VStack(spacing: 12) {
			Text("Who is growing up?")
				.font(.title.bold())
				.accessibilityAddTraits(.isHeader)
			Text("Add someone you love and watch their age count up, live to the second.")
				.font(.body)
				.foregroundStyle(.secondary)
		}
		.multilineTextAlignment(.center)
		.padding(32)
		// Wider than any iPhone, such as an iPhone Duo, the invitation stays a readable column.
		.frame(maxWidth: 440)
	}
}
