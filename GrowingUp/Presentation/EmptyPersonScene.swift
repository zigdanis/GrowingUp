import SwiftUI

struct EmptyPersonScene: View {
	let onAdd: () -> Void

	var body: some View {
		VStack(spacing: 24) {
			Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 72)).foregroundStyle(.tint)
			Button("Add person", systemImage: "plus", action: onAdd)
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
				.accessibilityIdentifier("person.add")
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground))
	}
}
