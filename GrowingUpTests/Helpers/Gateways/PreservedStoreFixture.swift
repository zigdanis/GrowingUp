import Foundation

@testable import Core

/// A temporary App Group in miniature for preserved-store tests: the store folder, loose photos at its root and an
/// exports folder. A space in the path, as in the App Group's `Application Support`, catches percent-encoded lookups.
struct PreservedStoreFixture {
	let root: URL
	var storeFolder: URL { root.appendingPathComponent("Application Support", isDirectory: true) }
	var store: URL { storeFolder.appendingPathComponent("GrowingUp.sqlite") }
	var exports: URL { root.appendingPathComponent("Exports", isDirectory: true) }
	var library: PreservedStoreLibrary { PreservedStoreLibrary(storeURL: store, photosDirectory: root, exportsDirectory: exports) }

	init() throws {
		root = FileManager.default.temporaryDirectory.appendingPathComponent("Preserved \(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: storeFolder, withIntermediateDirectories: true)
	}

	func remove() throws {
		try FileManager.default.removeItem(at: root)
	}

	/// Writes an active store's SQLite family, each file holding its own name.
	func writeFamily() throws {
		for suffix in ["", "-wal", "-shm"] {
			try Data("saved\(suffix)".utf8).write(to: URL(fileURLWithPath: store.path + suffix))
		}
	}

	/// A preserved folder as an earlier version of the app left it: the main SQLite file, no note.
	func legacyFolder(named name: String) throws -> URL {
		let folder = storeFolder.appendingPathComponent(name, isDirectory: true)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
		try Data("old people".utf8).write(to: folder.appendingPathComponent("GrowingUp.sqlite"))
		return folder
	}

	/// The SHA-256 of each SQLite file in `folder`.
	func digests(in folder: URL) throws -> [String: String] {
		var digests: [String: String] = [:]
		for name in ["GrowingUp.sqlite", "GrowingUp.sqlite-wal", "GrowingUp.sqlite-shm"] {
			let url = folder.appendingPathComponent(name)
			if FileManager.default.fileExists(atPath: url.path) { digests[name] = try ArchivedFile.digest(of: url) }
		}
		return digests
	}
}
