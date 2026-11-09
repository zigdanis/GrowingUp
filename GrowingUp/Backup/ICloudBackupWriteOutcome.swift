/// What one pass of the iCloud backup did.
enum ICloudBackupWriteOutcome: Sendable {
	/// The backup was written; its content hash.
	case written(String)
	/// The library is as the intact backup holds it already.
	case unchanged
	/// An empty library on an install without a backup: nothing to protect, and no empty backup that would look newer
	/// than the one to restore.
	case skipped
}
