import SwiftUI

/// The first rows of Settings' Backup section: the iCloud backup switch, and the list of backups in iCloud to restore
/// from or delete.
struct ICloudBackupRows: View {
	let presenter: BackupPresenter
	let backup: ICloudBackupService

	var body: some View {
		Toggle(isOn: Binding(get: { backup.isEnabled }, set: { backup.setEnabled($0) })) {
			Label("iCloud backup", systemImage: "icloud")
		}
		.accessibilityIdentifier("backup.icloud")
		NavigationLink {
			ICloudBackupsView(presenter: presenter, backup: backup)
		} label: {
			Label("Restore from iCloud", systemImage: "clock.arrow.circlepath")
		}
		.accessibilityIdentifier("backup.icloud.restore")
	}
}
