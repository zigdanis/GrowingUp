import Core
import Foundation

/// A backup read and checked, waiting for the person to confirm adding its people.
struct PendingRestore: Identifiable {
	let id = UUID()
	let backup: LoadedBackup
	let source: BackupRestoreSource

	var createdAt: Date { backup.document.createdAt }
	var peopleCount: Int { backup.document.people.count }
}
