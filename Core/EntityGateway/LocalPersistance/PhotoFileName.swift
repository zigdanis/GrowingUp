import Foundation

/// The names `DiskImageStore` gives a person's photo files: the picture's identifier with a `png`, `jpg` or `heic`
/// extension; see `PersonImage`.
enum PhotoFileName {
	private static let extensions: Set<String> = ["png", "jpg", "heic"]

	/// The picture identifier `name` belongs to, or nil for any other file.
	static func id(of name: String) -> UUID? {
		let url = URL(fileURLWithPath: name)
		guard extensions.contains(url.pathExtension.lowercased()) else { return nil }
		return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
	}

	static func isPhoto(_ name: String) -> Bool { id(of: name) != nil }
}
