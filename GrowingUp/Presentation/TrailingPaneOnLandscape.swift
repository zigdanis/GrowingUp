import SwiftUI

/// Centres content in the trailing half of a landscape window, clear of the fold between an iPhone Duo's two panes, and
/// leaves it as it is in the other layouts.
struct TrailingPaneOnLandscape: ViewModifier {
	let layout: PersonPageLayout
	/// The whole window, safe areas included.
	let window: CGSize
	/// The window's trailing safe area, which the content's frame already excludes.
	let trailingInset: CGFloat

	func body(content: Content) -> some View {
		if layout == .landscape {
			content
				.frame(width: max(0, window.width / 2 - trailingInset))
				.frame(maxWidth: .infinity, alignment: .trailing)
		} else {
			content
		}
	}
}
