import SwiftUI

/// The Settings section that backs the library up: with an iCloud backup, its switch and the backups to restore from
/// at the top; then the export of every person and photo to one file, and import from such a file. The footer says first
/// whether the library is safe in iCloud.
struct BackupFileSection: View {
	let presenter: BackupPresenter
	let onImport: () -> Void

	var body: some View {
		Section {
			if let iCloud = presenter.iCloud {
				ICloudBackupRows(presenter: presenter, backup: iCloud)
			}
			Button {
				Task { await presenter.startExport() }
			} label: {
				if presenter.export == .preparing {
					Label {
						Text("Preparing the export…")
					} icon: {
						ProgressView()
					}
				} else {
					Label("Export all data", systemImage: "square.and.arrow.up")
				}
			}
			.disabled(!presenter.isAvailable || presenter.isBusy)
			.accessibilityValue(presenter.export == .preparing ? Text("Preparing the export") : Text(""))
			.accessibilityIdentifier("backup.export")
			Button(action: onImport) {
				if presenter.isReading || presenter.isRestoring {
					Label {
						Text(presenter.isRestoring ? "Restoring…" : "Reading the file…")
					} icon: {
						ProgressView()
					}
				} else {
					Label("Import from file", systemImage: "square.and.arrow.down")
				}
			}
			.disabled(!presenter.isAvailable || presenter.isBusy)
			.accessibilityIdentifier("backup.import")
		} header: {
			Text("Backup")
		} footer: {
			if let iCloud = presenter.iCloud {
				VStack(alignment: .leading, spacing: 6) {
					Text(verbatim: BackupStatusText.describe(iCloud))
						.accessibilityIdentifier("backup.icloud.status")
					// The promise holds only while the backup is on and iCloud can take it.
					if iCloud.isEnabled, iCloud.availability != .unavailable {
						Text(
							"""
							Your people and photos are kept in your iCloud, so they stay safe if you delete the app or change \
							phones. The backup doesn't appear in iCloud Drive.
							"""
						)
					} else {
						exportFooter
					}
				}
				.task { iCloud.watchUpload() }
			} else {
				exportFooter
			}
		}
	}

	private var exportFooter: Text {
		Text(
			"""
			Export saves all your people and photos to one file. Import adds who is missing from such a file and never \
			deletes anyone.
			"""
		)
	}
}
