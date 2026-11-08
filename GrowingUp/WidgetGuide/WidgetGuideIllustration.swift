import SwiftUI

/// The picture on top of the widget guide, acting out the highlighted step; a decoration that VoiceOver skips, since the
/// steps below say the same.
struct WidgetGuideIllustration: View {
	let frame: WidgetGuideFrame
	/// The user's pinned people, as the real widget shows them; nil while they load.
	let entry: AgeEntry?
	let date: Date
	/// Whether the picture moves; never with Reduce Motion.
	let isAnimated: Bool

	var body: some View {
		ZStack {
			picture
				.id(frame)
				.transition(.opacity)
		}
		.animation(isAnimated ? .easeInOut(duration: 0.35) : nil, value: frame)
		.shadow(color: .black.opacity(0.25), radius: 12, y: 6)
		.accessibilityHidden(true)
	}

	@ViewBuilder
	private var picture: some View {
		switch frame {
		case .hold: WidgetGuideHoldFrame(isAnimated: isAnimated)
		case .swipe: WidgetGuideSwipeFrame(isAnimated: isAnimated)
		case .edit: WidgetGuideEditFrame(isAnimated: isAnimated)
		case .search: WidgetGuideSearchFrame(isAnimated: isAnimated)
		case .size: WidgetGuideSizeFrame(entry: entry, isAnimated: isAnimated)
		case .homeResult: WidgetGuideHomeResultFrame(entry: entry, isAnimated: isAnimated)
		case .todayResult: WidgetGuideTodayResultFrame(entry: entry, date: date, isAnimated: isAnimated)
		}
	}
}
