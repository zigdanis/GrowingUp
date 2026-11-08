import SwiftUI

/// The question before a restore, for the backups of one source: a picked file on Settings itself, a backup in iCloud on
/// the list of iCloud backups. Each page asks only for its own, so the question shows on the page that is on screen.
struct RestoreConfirmation: ViewModifier {
	@Bindable var presenter: BackupPresenter
	let source: BackupRestoreSource

	func body(content: Content) -> some View {
		content
			.confirmationDialog(
				"Restore this backup?", isPresented: isConfirming, titleVisibility: .visible, presenting: presenter.pendingRestore
			) { pending in
				Button("Restore") { presenter.confirmRestore(pending) }
					.accessibilityIdentifier("backup.restore.confirm")
				Button("Cancel", role: .cancel) { presenter.cancelRestore() }
			} message: { pending in
				Text(
					"""
					Saved \(pending.createdAt.formatted(date: .long, time: .shortened)). People: \(pending.peopleCount).

					Only who is missing is added, up to 20 people in all. Nothing in the app is changed or deleted.
					"""
				)
			}
	}

	private var isConfirming: Binding<Bool> {
		// Closing only forgets the question: SwiftUI may close it before or after running the chosen button.
		Binding(
			get: { presenter.pendingRestore?.source == source }, set: { if !$0 { presenter.dismissRestoreConfirmation() } })
	}
}
