import Core
import SwiftUI

/// A person's picture in a circle of `size` points, with a placeholder until it loads.
struct PersonPicture: View {
	let image: PersonImage?
	let loadImage: (PersonImage) async throws -> UIImage
	let identifier: String
	let label: Text
	let size: CGFloat
	let onError: (Error) -> Void

	var body: some View {
		PersonImageLoader(image: image, loadImage: loadImage, onError: onError) { loaded in
			ZStack {
				Circle().fill(.quaternary)
				if let loaded {
					Image(uiImage: loaded).resizable().scaledToFill()
						.accessibilityLabel(label)
						.accessibilityIdentifier("editor.\(identifier).loaded")
				} else {
					Image(systemName: "person.fill")
						.font(.system(size: size * 0.45))
						.foregroundStyle(.secondary)
						.accessibilityHidden(true)
				}
			}
			.frame(width: size, height: size)
			.clipShape(.circle)
		}
	}
}
