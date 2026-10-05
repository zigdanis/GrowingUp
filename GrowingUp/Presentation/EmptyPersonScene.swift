import SwiftUI

struct EmptyPersonScene: View {
	let onAdd: () -> Void

	var body: some View {
		Button(action: onAdd) {
			Image(systemName: "person.crop.circle.badge.plus")
				.font(.system(size: 72))
				.foregroundStyle(.tint)
				.padding(24)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(Text("Add person"))
		.accessibilityIdentifier("person.add")
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground))
	}
}
