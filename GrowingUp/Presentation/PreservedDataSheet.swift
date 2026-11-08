import Core
import SwiftUI

/// The sheet the corner capsule opens: the one preserved copy's details, or with several (recovery can happen again),
/// a list of them that each opens its own.
struct PreservedDataSheet: View {
	@Bindable var presenter: PreservedDataPresenter
	@State private var path: [PreservedStore] = []
	@Environment(\.dismiss)
	private var dismiss

	var body: some View {
		NavigationStack(path: $path) {
			Group {
				if presenter.stores.count > 1 {
					List(presenter.stores) { store in
						NavigationLink(value: store) {
							Text("Earlier data from \(store.preservedAt.formatted(date: .long, time: .omitted))")
						}
					}
					.navigationTitle("Earlier data")
					.navigationDestination(for: PreservedStore.self) { store in
						PreservedDataView(presenter: presenter, store: store)
					}
				} else if let store = presenter.newest {
					PreservedDataView(presenter: presenter, store: store)
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
		.presentationDetents([.medium, .large])
		// A deleted copy's page closes; with the last one gone, nothing is left to show.
		.onChange(of: presenter.stores.map(\.id)) { _, ids in
			path.removeAll { !ids.contains($0.id) }
			if ids.isEmpty { dismiss() }
		}
		.sheet(isPresented: isSharing) {
			if case .ready(let url) = presenter.export {
				ActivityShareSheet(url: url) { presenter.finishExport() }
					.presentationDetents([.medium, .large])
			}
		}
		.alert(
			presenter.failure?.title ?? "", isPresented: Binding(get: { presenter.failure != nil }, set: { if !$0 { presenter.failure = nil } })
		) {
			Button("OK", role: .cancel) { presenter.failure = nil }
		} message: {
			Text(presenter.failure?.message ?? "")
		}
	}

	private var isSharing: Binding<Bool> {
		Binding(
			get: { if case .ready = presenter.export { true } else { false } },
			set: { if !$0 { presenter.finishExport() } })
	}
}
