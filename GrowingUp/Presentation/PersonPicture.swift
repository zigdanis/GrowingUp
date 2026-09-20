import Core
import SwiftUI

struct PersonPicture: View {
	let image: PersonImage?
	let loadImage: (PersonImage) async throws -> UIImage
	let identifier: String
	let onError: (Error) -> Void
	@State private var loaded: UIImage?

	var body: some View {
		ZStack {
			Circle().fill(.quaternary)
			if let loaded {
				Image(uiImage: loaded).resizable().scaledToFill()
					.accessibilityLabel(Text("Selected photo"))
					.accessibilityIdentifier("editor.\(identifier).loaded")
			} else {
				Image(systemName: "photo.badge.plus").font(.largeTitle)
			}
		}
		.frame(width: 96, height: 96)
		.clipShape(.circle)
		.task(id: image?.id) {
			loaded = image?.uiImage
			guard let image, loaded == nil else { return }
			do {
				let picture = try await loadImage(image)
				try Task.checkCancellation()
				loaded = picture
			} catch is CancellationError {
			} catch {
				onError(error)
			}
		}
	}
}
