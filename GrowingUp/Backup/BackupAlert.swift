import Core
import Foundation

/// What the Backup sheet's alert tells after an export, an import or a restore.
enum BackupAlert: Identifiable, Equatable {
	case restored(RestoreSummary)
	/// The store refused the people, or the library could not be read first; nothing was added.
	case restoreFailed
	/// The backup could not be read; `reason` is nil for an error no `BackupError` names.
	case unreadable(BackupError?)
	case exportFailed

	var id: String {
		switch self {
		case .restored: "restored"
		case .restoreFailed: "restoreFailed"
		case .unreadable: "unreadable"
		case .exportFailed: "exportFailed"
		}
	}

	var title: String {
		switch self {
		case .restored: String(localized: "Backup restored")
		case .restoreFailed: String(localized: "Couldn't restore the backup")
		case .unreadable: String(localized: "Couldn't open the backup")
		case .exportFailed: String(localized: "Couldn't export the data")
		}
	}

	var message: String {
		switch self {
		case .restored(let summary):
			let everyoneHere = !summary.addedAnything && summary.peopleOverLimit == 0
			var lines = [
				everyoneHere
					? String(localized: "Everyone in this backup is already in the app.")
					: String(localized: "People added: \(summary.peopleAdded).")
			]
			if summary.peopleOverLimit > 0 {
				lines.append(String(localized: "Not added because the app keeps up to 20 people: \(summary.peopleOverLimit)."))
			}
			return lines.joined(separator: "\n")
		case .restoreFailed:
			return String(localized: "Nothing was changed. Try again.")
		case .unreadable(.newerVersion):
			return String(localized: "This backup was made by a newer version of GrowingUp. Update the app and try again.")
		case .unreadable(.notABackup), .unreadable(.photoUnavailable):
			return String(localized: "This file is not a GrowingUp backup, or it is damaged.")
		case .unreadable(nil):
			return String(localized: "Couldn't read the backup. Check your internet connection and try again.")
		case .exportFailed:
			return String(localized: "Your people and photos are still saved on this device. Try again in a moment.")
		}
	}
}
