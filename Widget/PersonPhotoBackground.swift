import SwiftUI
import UIKit
import WidgetKit

/// A person's tile picture filling its container: their photo or monogram, with the scrims that keep white text readable
/// already drawn in (see `PhotoScrim`).
struct PersonPhotoBackground: View {
	let person: WidgetPerson

	var body: some View {
		Color.clear
			.overlay {
				Image(uiImage: person.tilePicture)
					.resizable()
					.widgetAccentedRenderingMode(.fullColor)
					.scaledToFill()
			}
			.clipped()
			// The picture is decorative; the tile carries the label. Hidden, the scaled-to-fill image also cannot report its unclipped frame.
			.accessibilityHidden(true)
	}
}
