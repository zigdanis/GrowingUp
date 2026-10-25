import SwiftUI

/// A person's monogram filling its frame, in place of a missing photo on their page and in their edit mode: the same
/// gradient and initial as their mosaic tile and widget picture, painted sharp at any size.
struct PersonMonogram: View {
	let id: UUID
	let name: String

	var body: some View {
		Canvas { context, size in
			context.withCGContext { cgContext in
				MonogramPicture.paint(id: id, name: name, in: CGRect(origin: .zero, size: size), context: cgContext)
			}
		}
		.accessibilityHidden(true)
	}
}
