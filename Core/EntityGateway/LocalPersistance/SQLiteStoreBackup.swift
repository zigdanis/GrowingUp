import Foundation

struct SQLiteStoreBackup {
	var moveItem: (URL, URL) throws -> Void = FileManager.default.moveItem(at:to:)

	/// Keep the SQLite family together in a unique, timestamped sibling directory. No store files are deleted.
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
		// The atomic journal precedes every move and survives process termination. Every loader
		// resumes it under SQLiteStoreAccess before touching SQLite, even if the WAL moved first.
		let journal = url.appendingPathExtension("recovery")
		try Data(backup.lastPathComponent.utf8).write(to: journal, options: .atomic)
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
			var restored = true
			for source in moved.reversed() {
				do {
					try moveItem(backup.appendingPathComponent(source.lastPathComponent), source)
				} catch {
					restored = false
					Logging.logError(CoreError(message: "Store backup rollback failed; preserved files at \(backup.path): \(error)"))
				}
			}
			if restored { try? manager.removeItem(at: journal) }
			throw error
		}
		try manager.removeItem(at: journal)
		return backup
	}

	/// A journal exists only after a confirmed incompatible-model failure. Never open the
	/// original URL while it exists: the old main file might be separated from its WAL.
	func resumePendingMove(at url: URL) throws -> URL? {
		let journal = url.appendingPathExtension("recovery")
		let data: Data
		do {
			data = try Data(contentsOf: journal)
		} catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
			return nil
		}
		guard let name = String(data: data, encoding: .utf8),
			name.hasPrefix(url.lastPathComponent + ".backup-"), !name.contains("/")
		else { throw CoreError(message: "Invalid Core Data recovery journal at \(journal.path)") }
		let backup = url.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
		let manager = FileManager.default
		let remaining = try manager.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
		let preserved = try manager.contentsOfDirectory(atPath: backup.path)
		guard remaining.contains(url.lastPathComponent) || preserved.contains(url.lastPathComponent) else {
			throw CocoaError(.fileNoSuchFile)
		}
		for suffix in ["-wal", "-shm", ""] {
			let source = URL(fileURLWithPath: url.path + suffix)
			guard remaining.contains(source.lastPathComponent) else { continue }
			// A collision is an error; never overwrite either copy of user data.
			try moveItem(source, backup.appendingPathComponent(source.lastPathComponent))
		}
		try manager.removeItem(at: journal)
		return backup
	}
}
