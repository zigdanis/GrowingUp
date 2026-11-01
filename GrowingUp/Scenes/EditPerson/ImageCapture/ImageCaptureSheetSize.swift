import SwiftUI

/// The size of the sheet the photos and the camera open in: a page on iPad, whose sheets take no detents; on a phone, a
/// half-height sheet for the photos, which drags up to full height, and a full-height one for the camera.
struct ImageCaptureSheetSize: ViewModifier {
	let isPage: Bool
	let isCamera: Bool

	func body(content: Content) -> some View {
		if isPage {
			content.presentationSizing(.page)
		} else {
			content.presentationDetents(isCamera ? [.large] : [.medium, .large])
		}
	}
}
