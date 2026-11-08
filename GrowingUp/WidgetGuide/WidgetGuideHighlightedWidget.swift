import SwiftUI
import WidgetKit

/// The added widget in a guide result, ringed in the app colour; the ring glows softly while `isAnimated`.
struct WidgetGuideHighlightedWidget: View {
	let entry: AgeEntry?
	let family: WidgetFamily
	let isAnimated: Bool

	var body: some View {
		let size = WidgetPreview.nativeSize(of: family)
		Group {
			if let entry {
				WidgetPreview(entry: entry, family: family)
			} else {
				RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.1)).aspectRatio(size.width / size.height, contentMode: .fit)
			}
		}
		.overlay {
			if isAnimated {
				PhaseAnimator([1.0, 0.35]) { opacity in
					ring.opacity(opacity)
				} animation: { _ in
					.easeInOut(duration: 0.9)
				}
			} else {
				ring
			}
		}
	}

	private var ring: some View {
		RoundedRectangle(cornerRadius: 20, style: .continuous)
			.stroke(Color(uiColor: .appColor), lineWidth: 3)
			.padding(-1.5)
	}
}
