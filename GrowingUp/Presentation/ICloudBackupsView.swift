import Core
import SwiftUI

/// Settings → Restore from iCloud: every backup in the person's iCloud, newest first, one for each install of the app,
/// with an install's earlier copy when its latest can't be restored. A tap asks to restore one; a swipe deletes one from
/// iCloud. This list is the only place a backup can be seen or removed, since iCloud Drive does not show them.
struct ICloudBackupsView: View {
	@Bindable var presenter: BackupPresenter
	let backup: ICloudBackupService
	@State private var deletion: BackupCandidate?

	var body: some View {
		List {
			if backup.availability == .unavailable {
				Text("iCloud is not available. To keep a backup, sign in to iCloud in the Settings app and turn on iCloud Drive.")
					.foregroundStyle(.secondary)
			} else if backup.candidates.isEmpty {
				if backup.isLoadingCandidates || backup.availability == .checking {
					Label {
						Text("Looking for backups…")
					} icon: {
						ProgressView()
					}
					.foregroundStyle(.secondary)
				} else {
					Text("No backups in iCloud yet.")
						.foregroundStyle(.secondary)
				}
			} else {
				ForEach(backup.candidates) { candidate in
					row(candidate)
				}
			}
		}
		.navigationTitle("Restore from iCloud")
		.navigationBarTitleDisplayMode(.inline)
		.accessibilityIdentifier("backup.list")
		.task { await backup.refreshCandidates() }
		.refreshable { await backup.refreshCandidates() }
		.modifier(RestoreConfirmation(presenter: presenter, source: .icloud))
		.confirmationDialog(
			"Delete this backup from iCloud?", isPresented: isDeleting, titleVisibility: .visible, presenting: deletion
		) { candidate in
			Button("Delete Backup", role: .destructive) {
				Task { await presenter.delete(candidate) }
			}
			Button("Cancel", role: .cancel) {}
		} message: { _ in
			Text("Your people and photos in the app stay as they are.")
		}
	}

	private func row(_ candidate: BackupCandidate) -> some View {
		Button {
			Task { await presenter.open(candidate) }
		} label: {
			HStack(spacing: 12) {
				Image(systemName: candidate.deviceModel == "iPad" ? "ipad" : "iphone")
					.font(.title3)
					.foregroundStyle(.tint)
					.frame(width: 28)
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 3) {
					Text(candidate.createdAt.formatted(date: .abbreviated, time: .shortened))
						.foregroundStyle(.primary)
					Text(verbatim: subtitle(candidate))
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				Spacer(minLength: 8)
				if presenter.loadingCandidateID == candidate.id {
					ProgressView()
				}
			}
			.contentShape(.rect)
		}
		.disabled(!presenter.isAvailable || presenter.isBusy)
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			// Not a destructive role, which would slide the row away before the deletion is confirmed.
			Button {
				deletion = candidate
			} label: {
				Label("Delete Backup", systemImage: "trash")
			}
			.tint(.red)
		}
		.accessibilityIdentifier("backup.candidate")
	}

	/// Such as "This device · Earlier copy · People: 3".
	private func subtitle(_ candidate: BackupCandidate) -> String {
		var parts: [String] = []
		let device = candidate.isThisDevice ? String(localized: "This device") : candidate.deviceModel
		if !device.isEmpty { parts.append(device) }
		if candidate.isPreviousCopy { parts.append(String(localized: "Earlier copy")) }
		parts.append(String(localized: "People: \(candidate.peopleCount)"))
		return parts.joined(separator: " · ")
	}

	private var isDeleting: Binding<Bool> {
		Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })
	}
}
