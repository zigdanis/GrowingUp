import Core
import SwiftUI

/// Loads a person's picture, preferring its in-memory image, and renders `content` with the result.
struct PersonImageLoader<Content: View>: View {
	let image: PersonImage?
	let loadImage: (PersonImage) async throws -> UIImage
	let onError: (Error) -> Void
	@ViewBuilder let content: (UIImage?) -> Content
	@State private var loaded: UIImage?

	var body: some View {
		content(loaded)
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
