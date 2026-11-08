import SwiftUI
import WidgetKit

/// The app's real Home Screen widget, drawn by the extension's own views with the user's people and scaled to the
/// width it is given; a picture only, which takes no taps and VoiceOver skips.
struct WidgetPreview: View {
	let entry: AgeEntry
	let family: WidgetFamily

	/// The widget's size on a 6.3-inch iPhone, which the preview scales from.
	static func nativeSize(of family: WidgetFamily) -> CGSize {
		switch family {
		case .systemSmall: CGSize(width: 170, height: 170)
		case .systemMedium: CGSize(width: 364, height: 170)
		default: CGSize(width: 364, height: 382)
		}
	}

	var body: some View {
		let size = Self.nativeSize(of: family)
		Color.clear
			.aspectRatio(size.width / size.height, contentMode: .fit)
			.overlay(alignment: .topLeading) {
				GeometryReader { proxy in
					// Outside WidgetKit there is no container background, so the widget background is drawn directly, as
					// in the UI-test widget preview.
					AgeWidgetContentView(entry: entry, family: family)
						.frame(width: size.width, height: size.height)
						.background { AgeWidgetBackground(entry: entry, family: family) }
						.background(.background)
						.clipShape(.rect(cornerRadius: 24, style: .continuous))
						// A widget keeps its own text size; scaled down, a larger one would only break its tiles.
						.dynamicTypeSize(.large)
						.scaleEffect(proxy.size.width / size.width, anchor: .topLeading)
				}
			}
			.allowsHitTesting(false)
			.accessibilityHidden(true)
	}
}
