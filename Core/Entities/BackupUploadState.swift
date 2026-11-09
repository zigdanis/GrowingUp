/// Whether iCloud holds the whole of an install's latest backup yet: its document and every photo file it lists.
public enum BackupUploadState: Equatable, Sendable {
	case uploaded
	case uploading
	/// iCloud refused the upload, most often because the person's iCloud storage is full.
	case failed
	/// Not an iCloud file, as for a folder on the device or in tests.
	case notInICloud
}
