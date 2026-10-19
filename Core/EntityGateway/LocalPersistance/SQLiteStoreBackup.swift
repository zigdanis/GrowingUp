import Foundation

struct SQLiteStoreBackup {
	var moveItem: (URL, URL) throws -> Void = FileManager.default.moveItem(at:to:)

	/// Keep the SQLite family together in a unique, timestamped sibling directory. No files are deleted.
	func moveStore(at url: URL, date: Date = Date()) throws -> URL {
		let manager = FileManager.default
		let parent = url.deletingLastPathComponent()
		let names = try manager.contentsOfDirectory(atPath: parent.path)
		guard names.contains(url.lastPathComponent) else {
			throw CocoaError(.fileNoSuchFile)
		}
		let timestamp = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-")
		let backup = parent.appendingPathComponent("\(url.lastPathComponent).backup-\(timestamp)-\(UUID().uuidString)", isDirectory: true)
		try manager.createDirectory(at: backup, withIntermediateDirectories: false)
		var moved: [URL] = []
		do {
			// Move the main store last: a failed sidecar move must never leave a vacant store URL.
			for suffix in ["-wal", "-shm", ""] {
				let source = URL(fileURLWithPath: url.path + suffix)
				guard names.contains(source.lastPathComponent) else { continue }
				try moveItem(source, backup.appendingPathComponent(source.lastPathComponent))
				moved.append(source)
			}
		} catch {
			for source in moved.reversed() {
				do {
					try moveItem(backup.appendingPathComponent(source.lastPathComponent), source)
				} catch {
					Logging.logError(CoreError(message: "Store backup rollback failed; preserved files at \(backup.path): \(error)"))
				}
			}
			throw error
		}
		return backup
	}
}
