import Foundation

/// The SHA-256 of each backup photo file already read, by its path, size and modification date, so checking a backup's
/// photos before each write reads every file only once a launch; a changed file has a new size or date and is read again.
final class BackupDigestCache: @unchecked Sendable {
	static let shared = BackupDigestCache()

	private let lock = NSLock()
	private var digests: [String: String] = [:]

	/// The SHA-256 of the file at `url`, which must be on the device.
	func digest(of url: URL) throws -> String {
		let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
		let modified = (values.contentModificationDate ?? .distantPast).timeIntervalSinceReferenceDate
		let key = "\(url.path)|\(values.fileSize ?? 0)|\(modified)"
		lock.lock()
		let known = digests[key]
		lock.unlock()
		if let known { return known }
		let digest = try ArchivedFile.digest(of: url)
		lock.lock()
		digests[key] = digest
		lock.unlock()
		return digest
	}
}
