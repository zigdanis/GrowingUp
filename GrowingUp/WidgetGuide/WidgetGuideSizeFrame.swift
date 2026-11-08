import SwiftUI
import WidgetKit

/// Step 4: GrowingUp's page in the widget gallery, which swipes through the sizes, and "Add Widget".
struct WidgetGuideSizeFrame: View {
	let entry: AgeEntry?
	let isAnimated: Bool
	private static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]

	var body: some View {
		WidgetGuideCanvas {
			Color(red: 0.14, green: 0.14, blue: 0.15)
			HStack(spacing: 10) {
				AppIconImage(size: 32)
				VStack(alignment: .leading, spacing: 1) {
					Text(verbatim: "GrowingUp").font(.system(size: 15, weight: .semibold))
					Text("See up to six pinned people and their live age.").font(.system(size: 12)).opacity(0.6).lineLimit(1)
				}
			}
			.padding([.top, .horizontal], 16)
			if isAnimated {
				// The sizes pass by as a finger would swipe through them, pausing on each.
				PhaseAnimator([1, 2, 0]) { index in
					sizes(selected: index)
				} animation: { _ in
					.easeInOut(duration: 0.35).delay(0.6)
				}
			} else {
				sizes(selected: 1)
			}
			Label("Add Widget", systemImage: "plus")
				.font(.system(size: 16, weight: .semibold))
				.frame(width: 353 - 60, height: 44)
				.background(Color.blue, in: .capsule)
				.offset(x: 30, y: 300 - 14 - 44)
		}
		.foregroundStyle(.white)
	}

	private func sizes(selected: Int) -> some View {
		VStack(spacing: 14) {
			ZStack {
				if let entry {
					WidgetPreview(entry: entry, family: Self.families[selected])
						.id(selected)
						.transition(.opacity)
				} else {
					RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.1))
				}
			}
			.frame(width: 273, height: 127)
			HStack(spacing: 7) {
				ForEach(Self.families.indices, id: \.self) { index in
					Circle().fill(.white.opacity(index == selected ? 1 : 0.3)).frame(width: 7, height: 7)
				}
			}
		}
		.frame(width: 353)
		.offset(y: 72)
	}
}
