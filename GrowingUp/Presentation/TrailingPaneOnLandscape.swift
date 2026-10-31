import SwiftUI

/// Centres content in the trailing half of a landscape window that may span a fold, clear of the fold between an
/// iPhone Duo's two panes, and leaves it as it is in the other windows, an iPad's included.
struct TrailingPaneOnLandscape: ViewModifier {
	let layout: PersonPageLayout
	/// Whether the window may span a fold; see `PersonPageLayout.spansFold(idiom:)`.
	let spansFold: Bool
	/// The whole window, safe areas included.
	let window: CGSize
	/// The window's trailing safe area, which the content's frame already excludes.
	let trailingInset: CGFloat

	func body(content: Content) -> some View {
		if layout == .landscape, spansFold {
			content
				.frame(width: max(0, window.width / 2 - trailingInset))
				.frame(maxWidth: .infinity, alignment: .trailing)
		} else {
			content
		}
	}
}
