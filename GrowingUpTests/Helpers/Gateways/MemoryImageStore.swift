import Core
import UIKit

/// Keeps pictures and originals in memory, encoded the way the disk store encodes them, and counts originals written.
final class MemoryImageStore: ImageStore {
	private(set) var files: [String: Data] = [:]
	private(set) var originalWrites = 0

	func save(_ image: PersonImage) async throws {
		guard let data = image.uiImage?.pngData() else { throw CoreError.missingValue }
		files[image.cachingKey] = data
	}

	func saveOriginal(_ image: PersonImage) async throws {
		let file = try OriginalPhotoFile.encode(image)
		files[file.name] = file.data
		originalWrites += 1
	}

	func delete(_ image: PersonImage) async throws {
		for name in OriginalPhotoFile.names(for: image) { files[name] = nil }
	}

	/// Whether anything is stored under `id`, in any format.
	func contains(_ id: UUID?) -> Bool {
		guard let image = PersonImage(id: id) else { return false }
		return OriginalPhotoFile.names(for: image).contains { files[$0] != nil }
	}

	func load(_ image: PersonImage) async throws -> UIImage {
		try decode(files[image.cachingKey])
	}

	func loadOriginal(_ image: PersonImage) async throws -> UIImage {
		try decode(OriginalPhotoFile.names(for: image).lazy.compactMap { self.files[$0] }.first)
	}

	private func decode(_ data: Data?) throws -> UIImage {
		guard let data, let image = UIImage(data: data) else { throw CoreError.missingValue }
		return image
	}
}
