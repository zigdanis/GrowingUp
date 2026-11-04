import SwiftUI

/// The mosaic's floating capsule in the app colour: the one control on the home screen, so it may be bright. It offers
/// "Add" and, while the mosaic is reordering, "Done" in its place.
///
/// It keeps to one line, growing up to a size that leaves the mosaic room; beyond it, a long press shows it in the large
/// content viewer, like the edit mode's Cancel and Done.
///
/// A `zoomSource` makes the button the source of a zoom transition, with its shadow kept on the source.
struct FloatingCapsuleButton: View {
	let title: LocalizedStringKey
	let systemImage: String
	let action: () -> Void
	/// Where a zoom transition grows out of the button, if one does.
	var zoomSource: (id: UUID?, namespace: Namespace.ID)?
	/// The capsule's height, whose half rounds the iOS 18 transition source into the capsule.
	@State private var height: CGFloat = 0

	private static var shadowColor: Color { Color(uiColor: .appColor).opacity(0.4) }
	private static let shadowRadius: CGFloat = 12
	private static let shadowOffset: CGFloat = 8

	var body: some View {
		let button = Button(action: action) {
			Label(title, systemImage: systemImage)
				.font(.headline)
				// About half an iPhone's width, the size of a primary action without crowding the tiles.
				.frame(minWidth: 160, minHeight: 34)
		}
		.modifier(GlassCapsuleButtonChrome(prominent: true))
		.controlSize(.large)
		.lineLimit(1)
		.dynamicTypeSize(...DynamicTypeSize.accessibility1)
		.accessibilityShowsLargeContentViewer()
		.onGeometryChange(for: CGFloat.self) { geometry in
			geometry.size.height
		} action: { newHeight in
			height = newHeight
		}
		withShadow(button)
	}

	@ViewBuilder
	private func withShadow(_ button: some View) -> some View {
		if let zoomSource {
			if #available(iOS 26.0, *) {
				// The glass press effect grows past the button's bounds, so the source is not clipped here.
				button
					.shadow(color: Self.shadowColor, radius: Self.shadowRadius, y: Self.shadowOffset)
					.matchedTransitionSource(id: zoomSource.id, in: zoomSource.namespace)
			} else {
				// On iOS 18 the transition source is drawn on a rectangular plate clipped to its frame, which would show
				// as a white rectangle behind the capsule and cut off its shadow. Styling the source itself as the
				// capsule, with the shadow, avoids both; the source clips only to rounded rectangles, so a capsule's radius.
				button.matchedTransitionSource(id: zoomSource.id, in: zoomSource.namespace) { source in
					source
						.background(.clear)
						.clipShape(.rect(cornerRadius: height / 2))
						.shadow(color: Self.shadowColor, radius: Self.shadowRadius, x: 0, y: Self.shadowOffset)
				}
			}
		} else {
			button.shadow(color: Self.shadowColor, radius: Self.shadowRadius, y: Self.shadowOffset)
		}
	}
}
