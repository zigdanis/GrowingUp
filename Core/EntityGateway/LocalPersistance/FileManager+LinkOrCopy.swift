import Foundation

extension FileManager {
	/// Adds a hard link to `source` at `destination`, which takes no space and outlives `source` being removed; where the
	/// volume refuses links, a copy.
	func linkOrCopyItem(at source: URL, to destination: URL) throws {
		do {
			try linkItem(at: source, to: destination)
		} catch {
			// A link that failed half way must not stop the copy.
			if fileExists(atPath: destination.path) { throw error }
			try copyItem(at: source, to: destination)
		}
	}
}
