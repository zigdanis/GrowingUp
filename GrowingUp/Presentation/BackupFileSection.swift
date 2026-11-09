import SwiftUI

/// The Settings section that backs the library up: its export of every person and photo to one file, and import from
/// such a file.
struct BackupFileSection: View {
	let presenter: BackupPresenter
	let onImport: () -> Void

	var body: some View {
		Section {
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
			Text(
				"""
				Export saves all your people and photos to one file. Import adds who is missing from such a file and never \
				deletes anyone.
				"""
			)
		}
	}
}
