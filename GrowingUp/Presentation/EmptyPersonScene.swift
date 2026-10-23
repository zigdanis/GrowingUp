import SwiftUI

struct EmptyPersonScene: View {
	let onAdd: () -> Void
	/// How far up from the bottom of this page the floating avatar strip reaches, so the invitation keeps clear of it.
	let stripClearance: CGFloat
	/// The empty margin around the invitation, which may overlap the strip: only its text and button must stay clear.
	private static let margin: CGFloat = 32

	var body: some View {
		let stripReach = max(0, stripClearance - Self.margin)
		// Each option is measured at its intrinsic height, since the content's flexible frame reports that when unconstrained.
		ViewThatFits(in: .vertical) {
			// Centered in the whole page while the strip stays clear of it.
			content.padding(.vertical, stripReach)
			// The avatar strip floats over the bottom of this page, so the scrolling ends above it.
			ScrollView { content }.padding(.bottom, stripClearance)
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
		.padding(Self.margin)
		// Wider than any iPhone, such as an iPhone Duo, the invitation stays a readable centered column.
		.frame(maxWidth: 440)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
