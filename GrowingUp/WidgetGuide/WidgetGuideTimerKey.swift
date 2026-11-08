/// What restarts the widget guide's beat timer: another tab, a tapped step, or Reduce Motion switched.
struct WidgetGuideTimerKey: Hashable {
	let tab: WidgetGuideTab
	let restarts: Int
	let isAnimated: Bool
}
