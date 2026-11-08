/// Which step of the widget guide is highlighted and which picture plays.
///
/// The four steps take a beat each, and a fifth beat shows the result with the last step still highlighted; then it all
/// starts over. A tapped step plays from there. With Reduce Motion nothing advances on its own, and each step shows its
/// own still picture.
struct WidgetGuidePlayback: Equatable {
	/// How long each beat lasts, in seconds.
	static let beatDuration = 3
	static let stepCount = 4

	private(set) var tab: WidgetGuideTab = .homeScreen
	/// 0 to 3 for the steps, 4 for the result.
	private(set) var beat = 0

	/// The highlighted step, 0 to 3.
	var step: Int { min(beat, Self.stepCount - 1) }

	var frame: WidgetGuideFrame {
		switch beat {
		case 0: tab == .homeScreen ? .hold : .swipe
		case 1: .edit
		case 2: .search
		case 3: .size
		default: tab == .homeScreen ? .homeResult : .todayResult
		}
	}

	/// The next beat, after the result the first step again.
	mutating func advance() {
		beat = (beat + 1) % (Self.stepCount + 1)
	}

	mutating func jump(to step: Int) {
		beat = min(max(step, 0), Self.stepCount - 1)
	}

	/// Another tab plays from its first step.
	mutating func show(_ tab: WidgetGuideTab) {
		guard tab != self.tab else { return }
		self.tab = tab
		beat = 0
	}
}
