import SwiftUI

struct LimitedAccessHeader: View {
	let onSelectMore: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: "checklist").foregroundStyle(.secondary)
			Text("You've allowed access to a limited set of photos.")
				.font(.footnote)
				.foregroundStyle(.secondary)
			Spacer(minLength: 8)
			Button("Select More", action: onSelectMore).font(.footnote.weight(.semibold))
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.frame(maxWidth: .infinity)
		.background(.bar)
	}
}
