import CryptoKit
import Foundation

/// One file of an exported preserved store, as its `manifest.json` lists it.
struct ArchivedFile: Codable, Equatable {
	/// The file's place in the archive, such as `Store/GrowingUp.sqlite`.
	let path: String
	let size: Int
	/// The SHA-256 of the file's bytes, in lowercase hexadecimal.
	let sha256: String

	init(path: String, size: Int, sha256: String) {
		self.path = path
		self.size = size
		self.sha256 = sha256
	}

	init(at url: URL, path: String) throws {
		let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
		self.init(path: path, size: size ?? 0, sha256: try Self.digest(of: url))
	}

	/// Reads the file a megabyte at a time, so a large photo never sits in memory whole.
	static func digest(of url: URL) throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }
		var hasher = SHA256()
		while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
			hasher.update(data: chunk)
		}
		return hasher.finalize().map { String(format: "%02x", $0) }.joined()
	}
}
