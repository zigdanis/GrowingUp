import SwiftUI

struct EmptyPersonScene: View {
	let onAdd: () -> Void

	var body: some View {
		ViewThatFits(in: .vertical) {
			content
			// The avatar strip floats over the bottom of this page, so the scrolled content ends above it.
			ScrollView { content.padding(.bottom, 96) }
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground))
	}

	private var content: some View {
		VStack(spacing: 16) {
			Image(systemName: "person.crop.circle.badge.plus")
				.font(.system(size: 72))
				.foregroundStyle(.tint)
				.accessibilityHidden(true)
			Text("Who is growing up?")
				.font(.title.bold())
				.accessibilityAddTraits(.isHeader)
			Text("Add someone you love and watch their age count up, live to the second.")
				.font(.body)
				.foregroundStyle(.secondary)
			Button(action: onAdd) {
				Label("Add person", systemImage: "plus")
					.font(.headline)
					.padding(.horizontal, 8)
			}
			.modifier(GlassCapsuleButtonChrome(prominent: true))
			.controlSize(.large)
			.padding(.top, 8)
			.accessibilityIdentifier("person.add")
		}
		.multilineTextAlignment(.center)
		.padding(32)
		// Wider than any iPhone, such as an iPhone Duo, the invitation stays a readable centered column.
		.frame(maxWidth: 440)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
