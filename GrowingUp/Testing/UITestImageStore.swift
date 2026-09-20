#if DEBUG
	import Core
	import UIKit

	final class UITestImageStore: ImageStore {
		let root: URL
		init(root: URL) { self.root = root }

		func save(_ image: PersonImage) async throws {
			guard let data = image.uiImage?.jpegData(compressionQuality: 0.95) else { throw CoreError.missingValue }
			try data.write(to: root.appendingPathComponent(image.cachingKey), options: .atomic)
		}

		func delete(_ image: PersonImage) async throws {
			try FileManager.default.removeItem(at: root.appendingPathComponent(image.cachingKey))
		}

		func load(_ image: PersonImage) async throws -> UIImage {
			let data = try Data(contentsOf: root.appendingPathComponent(image.cachingKey))
			guard let result = UIImage(data: data) else { throw CoreError.missingValue }
			return result
		}
	}
#endif
