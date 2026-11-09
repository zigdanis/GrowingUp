/// Why a backup could not be read or restored; nothing in the app changes in any of these cases.
public enum BackupError: Error, Equatable, Sendable {
	/// The file is not a GrowingUp backup, or its contents do not make sense.
	case notABackup
	/// A newer version of the app wrote it, in a format this one can't read.
	case newerVersion
	/// A photo it lists is missing or its bytes do not match, as with a file iCloud has not finished downloading. Trying
	/// again may succeed; restoring without the photo would lose it for good, since a later restore skips people already
	/// here.
	case photoUnavailable
}
