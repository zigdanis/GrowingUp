#if DEBUG
	import Core
	import UIKit

	final class UITestImageStore: ImageStore {
		let root: URL
		init(root: URL) { self.root = root }

		func save(_ image: PersonImage) async throws {
			try store(image)
		}

		/// Writes synchronously so seeding can add pictures before the first scene loads them.
		func store(_ image: PersonImage) throws {
			guard let data = image.uiImage?.pngData() else { throw CoreError.missingValue }
			try data.write(to: root.appendingPathComponent(image.cachingKey), options: .atomic)
		}

		func saveOriginal(_ image: PersonImage) async throws {
			let file = try OriginalPhotoFile.encode(image)
			try file.data.write(to: root.appendingPathComponent(file.name), options: .atomic)
		}

		/// Removes the picture in whichever format it was stored; a missing one is an error, as for a real store's caller.
		func delete(_ image: PersonImage) async throws {
			let names = OriginalPhotoFile.names(for: image).filter { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
			guard !names.isEmpty else { throw CocoaError(.fileNoSuchFile) }
			for name in names { try FileManager.default.removeItem(at: root.appendingPathComponent(name)) }
		}

		func load(_ image: PersonImage) async throws -> UIImage {
			let data = try Data(contentsOf: root.appendingPathComponent(image.cachingKey))
			guard let result = UIImage(data: data) else { throw CoreError.missingValue }
			return result
		}

		func loadOriginal(_ image: PersonImage) async throws -> UIImage {
			let urls = OriginalPhotoFile.names(for: image).map { root.appendingPathComponent($0) }
			guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { throw CoreError.missingValue }
			return try await ImagesCache.loadFullSize(at: url)
		}

		func loadThumbnail(_ image: PersonImage, maxPixelSize: Int) async throws -> UIImage {
			try await ImagesCache.loadThumbnail(at: root.appendingPathComponent(image.cachingKey), maxPixelSize: maxPixelSize)
		}
	}
#endif
