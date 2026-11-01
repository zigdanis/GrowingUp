import SwiftUI

/// Keeps content clear of the close, minimize and tile controls that an iPadOS window draws over its top-leading
/// corner: the content moves past them along `edges` and narrows to fit. Where no controls show, as full screen or on
/// iPhone, it stays where it is.
struct WindowControlsClearance: ViewModifier {
	let edges: Edge.Set

	func body(content: Content) -> some View {
		if #available(iOS 26, *), UIDevice.current.userInterfaceIdiom == .pad {
			content.containerCornerOffset(edges, sizeToFit: true)
		} else {
			content
		}
	}
}
