import Core
import Foundation

/// The line at the top of the Backup section's footer that says whether the library is safe in iCloud.
enum BackupStatusText {
	@MainActor
	static func describe(_ backup: ICloudBackupService, now: Date = Date()) -> String {
		describe(
			isEnabled: backup.isEnabled, availability: backup.availability, isBackingUp: backup.isBackingUp,
			lastBackupAt: backup.lastBackupAt, uploadState: backup.uploadState, lastWriteFailed: backup.lastWriteFailed, now: now)
	}

	// swiftlint:disable:next function_parameter_count
	static func describe(
		isEnabled: Bool, availability: ICloudBackupAvailability, isBackingUp: Bool, lastBackupAt: Date?,
		uploadState: BackupUploadState?, lastWriteFailed: Bool, now: Date
	) -> String {
		guard isEnabled else {
			return String(
				localized: """
					iCloud backup is off. New changes stay only on this device. Earlier backups remain in iCloud until you \
					delete them in Restore from iCloud.
					""")
		}
		switch availability {
		case .checking:
			return String(localized: "Checking iCloud…")
		case .unavailable:
			return String(
				localized: "iCloud is not available. To keep a backup, sign in to iCloud in the Settings app and turn on iCloud Drive.")
		case .available:
			break
		}
		if lastWriteFailed {
			return String(localized: "Couldn't save the backup. Check that this device has free space.")
		}
		if uploadState == .failed {
			return String(localized: "Couldn't upload the backup. Check that your iCloud storage is not full.")
		}
		if isBackingUp {
			return String(localized: "Backing up…")
		}
		guard let lastBackupAt else {
			return String(localized: "Your people and photos are backed up to iCloud after each change.")
		}
		let formatter = RelativeDateTimeFormatter()
		formatter.dateTimeStyle = .named
		formatter.unitsStyle = .full
		// A backup written a moment ago may carry a time a hair after the clock's.
		let time = formatter.localizedString(for: min(lastBackupAt, now), relativeTo: now)
		if uploadState == .uploading {
			return String(localized: "Last backup \(time). Uploading to iCloud…", comment: "Relative time, such as 2 minutes ago.")
		}
		return String(localized: "Last backup \(time).", comment: "Relative time, such as 2 minutes ago.")
	}
}
