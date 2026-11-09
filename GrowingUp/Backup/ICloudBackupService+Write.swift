import Core
import Foundation

extension ICloudBackupService {
	/// Writes `snapshot` into this install's `folder` unless it holds the same library already, intact.
	nonisolated static func write(
		_ snapshot: LibrarySnapshot, to folder: BackupFolder, lastHash: String?
	) throws -> ICloudBackupWriteOutcome {
		let hash = try BackupCodec.contentHash(of: snapshot.document)
		let exists = folder.hasDocument
		// An unchanged library needs no write, unless the backup is gone, as when deleted from another device, or damaged.
		if hash == lastHash, exists, folder.isIntact { return .unchanged }
		if snapshot.document.isEmpty, !exists { return .skipped }
		try folder.write(snapshot)
		return .written(hash)
	}
}
