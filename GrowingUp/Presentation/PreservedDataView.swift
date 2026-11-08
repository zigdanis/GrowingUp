import Core
import SwiftUI

/// One preserved copy: what happened, honestly, without promising it back; when it was set aside and how large it is;
/// its export; and its deletion, which only a confirmation allows.
struct PreservedDataView: View {
	let presenter: PreservedDataPresenter
	let store: PreservedStore
	@State private var confirmsDeletion = false

	var body: some View {
		List {
			Section {
				VStack(alignment: .leading, spacing: 12) {
					Image(systemName: "archivebox")
						.font(.largeTitle)
						.foregroundStyle(.tint)
						.accessibilityHidden(true)
					Text("Your earlier people and photos are kept")
						.font(.headline)
						.accessibilityAddTraits(.isHeader)
					Text(
						"""
						This version of GrowingUp couldn't open what was saved on this device before, so it set that data \
						aside and started with an empty list. Nothing was deleted.
						"""
					)
					Text(
						"""
						The app can't bring these people back by itself yet. A newer version may be able to. To be safe, \
						export a copy now and keep it outside the app, for example in Files.
						"""
					)
				}
				.padding(.vertical, 4)
			}
			Section {
				LabeledContent("Set aside", value: store.preservedAt.formatted(date: .long, time: .shortened))
				LabeledContent("Size", value: store.byteCount.formatted(.byteCount(style: .file)))
			}
			Section {
				Button {
					Task { await presenter.startExport(store) }
				} label: {
					if presenter.export == .preparing {
						Label {
							Text("Preparing the copy…")
						} icon: {
							ProgressView()
						}
					} else {
						Label("Export a copy…", systemImage: "square.and.arrow.up")
					}
				}
				.disabled(presenter.export == .preparing || presenter.isDeleting)
				.accessibilityValue(presenter.export == .preparing ? Text("Preparing the copy") : Text(""))
				.accessibilityIdentifier("preservedData.export")
			} footer: {
				Text(
					"""
					One file with your earlier people, their photos and a short note about what it contains. You choose \
					where it goes; the app never sends it anywhere by itself.
					"""
				)
			}
			Section {
				Button(role: .destructive) {
					confirmsDeletion = true
				} label: {
					Label("Delete preserved copy…", systemImage: "trash")
				}
				.disabled(presenter.export == .preparing || presenter.isDeleting)
				.accessibilityIdentifier("preservedData.delete")
			}
		}
		.navigationTitle("Earlier data")
		.confirmationDialog("Delete the preserved copy?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
			Button("Delete Copy", role: .destructive) {
				Task { await presenter.delete(store) }
			}
		} message: {
			Text("Your earlier people will be gone from this device for good. Export a copy first if you haven't.")
		}
	}
}
