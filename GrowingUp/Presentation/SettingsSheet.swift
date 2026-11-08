import Core
import SwiftUI
import UniformTypeIdentifiers

/// Settings, which the home screen's corner button opens: the earlier data store recovery set aside, while there is any;
/// the library's backup, export to a file and import from one; the Home Screen widget guide; and the privacy policy,
/// the developer's address and the app's version.
struct SettingsSheet: View {
	@Bindable var backup: BackupPresenter
	@Bindable var preserved: PreservedDataPresenter
	/// The pinned people as the widget guide shows them; nil while they load.
	let widgetPreview: AgeEntry?
	@Binding var isShowingWidgetGuide: Bool
	let now: () -> Date
	@State private var path: [PreservedStore]
	@State private var isPickingFile = false
	@Environment(\.dismiss)
	private var dismiss

	/// - Parameter preservedStore: The earlier data to open at once, as the "Earlier data preserved" capsule does.
	init(
		backup: BackupPresenter, preserved: PreservedDataPresenter, widgetPreview: AgeEntry?, isShowingWidgetGuide: Binding<Bool>,
		now: @escaping () -> Date, preservedStore: PreservedStore?
	) {
		self.backup = backup
		self.preserved = preserved
		self.widgetPreview = widgetPreview
		_isShowingWidgetGuide = isShowingWidgetGuide
		self.now = now
		_path = State(initialValue: preservedStore.map { [$0] } ?? [])
	}

	var body: some View {
		NavigationStack(path: $path) {
			List {
				if !preserved.stores.isEmpty {
					BackupRecoverySection(stores: preserved.stores)
				}
				BackupFileSection(presenter: backup, onImport: { isPickingFile = true })
				SettingsWidgetSection { isShowingWidgetGuide = true }
				SettingsAboutSection(version: .current)
			}
			.navigationTitle("Settings")
			.navigationBarTitleDisplayMode(.inline)
			.navigationDestination(for: PreservedStore.self) { store in
				PreservedDataView(presenter: preserved, store: store)
			}
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
			.fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.zip]) { result in
				guard case .success(let url) = result else { return }
				Task { await backup.open(pickedFile: url) }
			}
			.confirmationDialog(
				"Restore this backup?", isPresented: isConfirmingRestore, titleVisibility: .visible, presenting: backup.pendingRestore
			) { pending in
				Button("Restore") { backup.confirmRestore(pending) }
				Button("Cancel", role: .cancel) { backup.cancelRestore() }
			} message: { pending in
				Text(
					"""
					Saved \(pending.createdAt.formatted(date: .long, time: .shortened)). People: \(pending.peopleCount).

					Only who is missing is added, up to 20 people in all. Nothing in the app is changed or deleted.
					"""
				)
			}
			.sheet(isPresented: isSharingBackup) {
				if case .ready(let url) = backup.export {
					ActivityShareSheet(url: url) { backup.finishExport() }
						.presentationDetents([.medium, .large])
				}
			}
			.alert(backup.alert?.title ?? "", isPresented: showsBackupAlert, presenting: backup.alert) { _ in
				Button("OK", role: .cancel) { backup.alert = nil }
			} message: { alert in
				Text(alert.message)
			}
		}
		// Pushed pages, such as the earlier data, need the whole height.
		.presentationDetents([.large])
		.presentationDragIndicator(.visible)
		.sheet(isPresented: $isShowingWidgetGuide) {
			WidgetGuideSheet(entry: widgetPreview, now: now)
		}
		// A deleted copy's page closes.
		.onChange(of: preserved.stores.map(\.id)) { _, ids in
			path.removeAll { !ids.contains($0.id) }
		}
		.sheet(isPresented: isSharingPreservedData) {
			if case .ready(let url) = preserved.export {
				ActivityShareSheet(url: url) { preserved.finishExport() }
					.presentationDetents([.medium, .large])
			}
		}
		.alert(preserved.failure?.title ?? "", isPresented: showsPreservedFailure) {
			Button("OK", role: .cancel) { preserved.failure = nil }
		} message: {
			Text(preserved.failure?.message ?? "")
		}
	}

	private var isConfirmingRestore: Binding<Bool> {
		// Closing only forgets the question: SwiftUI may close it before or after running the chosen button.
		Binding(get: { backup.pendingRestore != nil }, set: { if !$0 { backup.dismissRestoreConfirmation() } })
	}

	private var showsBackupAlert: Binding<Bool> {
		Binding(get: { backup.alert != nil }, set: { if !$0 { backup.alert = nil } })
	}

	private var showsPreservedFailure: Binding<Bool> {
		Binding(get: { preserved.failure != nil }, set: { if !$0 { preserved.failure = nil } })
	}

	private var isSharingBackup: Binding<Bool> {
		Binding(
			get: { if case .ready = backup.export { true } else { false } },
			set: { if !$0 { backup.finishExport() } })
	}

	private var isSharingPreservedData: Binding<Bool> {
		Binding(
			get: { if case .ready = preserved.export { true } else { false } },
			set: { if !$0 { preserved.finishExport() } })
	}
}
