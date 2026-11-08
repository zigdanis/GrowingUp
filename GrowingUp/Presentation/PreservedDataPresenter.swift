import Core
import Foundation
import Observation

/// The earlier libraries store recovery set aside, which the app keeps visible until the person no longer needs the
/// notice, and their export. Store recovery may run in the widget's process, so the app learns of it from the files a
/// recovery leaves, whenever it refreshes: at launch and on each return to the foreground.
@MainActor
@Observable
final class PreservedDataPresenter {
	/// Every preserved store, newest first; empty when nothing was ever set aside.
	private(set) var stores: [PreservedStore] = []
	private(set) var export: PreservedDataExport = .idle
	/// Whether a confirmed deletion is under way.
	private(set) var isDeleting = false
	/// What the sheet's alert explains: an export or a deletion that failed.
	var failure: PreservedDataFailure?
	@ObservationIgnored private let gateway: PreservedStoreGateway?
	@ObservationIgnored private let analytics: AnalyticsGateway
	@ObservationIgnored private var refreshing: Task<Void, Never>?

	init(gateway: PreservedStoreGateway?, analytics: AnalyticsGateway) {
		self.gateway = gateway
		self.analytics = analytics
	}

	var newest: PreservedStore? { stores.first }

	/// Reads the preserved stores again, keeps the photos of one an earlier version set aside with it, and reports each
	/// new recovery once, with only its cause's category. Refreshes run one after another, so none reports a store twice.
	func refresh() async {
		guard gateway != nil else { return }
		let previous = refreshing
		let refresh = Task { [weak self] in
			await previous?.value
			await self?.performRefresh()
		}
		refreshing = refresh
		await refresh.value
	}

	private func performRefresh() async {
		guard let gateway else { return }
		let (stores, failures) = await Task.detached(priority: .utility) { () -> ([PreservedStore], [AnalyticsFailure]) in
			var stores: [PreservedStore]
			do {
				stores = try gateway.stores()
			} catch {
				return ([], [AnalyticsFailure(operation: "read_preserved_data", error: error)])
			}
			var failures: [AnalyticsFailure] = []
			for (index, store) in stores.enumerated() {
				if !store.hasPreservedPhotos {
					do {
						stores[index] = try gateway.preservePhotos(of: store)
					} catch {
						failures.append(AnalyticsFailure(operation: "preserve_photos", error: error))
					}
				}
				guard !stores[index].isReported else { continue }
				failures.append(AnalyticsFailure(operation: "recover_store", error: store.cause.reportedError))
				// A note that fails to save reports the recovery again next time: twice is better than never.
				if let reported = try? gateway.markReported(stores[index]) { stores[index] = reported }
			}
			return (stores, failures)
		}.value
		self.stores = stores
		for failure in failures { analytics.report(failure) }
	}

	/// Writes `store` as an archive for the share sheet. Nothing is sent: only the person's choice in the sheet moves it.
	func startExport(_ store: PreservedStore) async {
		guard let gateway, export != .preparing else { return }
		gateway.removeExports()
		export = .preparing
		let result = await Task.detached(priority: .userInitiated) {
			Result { try gateway.export(store, now: Date()) }
		}.value
		switch result {
		case .success(let archive):
			export = .ready(archive)
			analytics.track(.preservedDataExported)
		case .failure(let error):
			export = .idle
			failure = .export
			analytics.report(AnalyticsFailure(operation: "export_preserved_data", error: error))
		}
	}

	/// Deletes `store` for good, which the person confirmed.
	func delete(_ store: PreservedStore) async {
		guard let gateway, !isDeleting else { return }
		isDeleting = true
		defer { isDeleting = false }
		let result = await Task.detached(priority: .userInitiated) {
			Result { try gateway.delete(store) }
		}.value
		switch result {
		case .success:
			stores.removeAll { $0.id == store.id }
		case .failure(let error):
			failure = .delete
			analytics.report(AnalyticsFailure(operation: "delete_preserved_data", error: error))
		}
	}

	/// Forgets the archive once the share sheet closed, and removes it from the device's temporary files.
	func finishExport() {
		guard export != .preparing else { return }
		export = .idle
		gateway?.removeExports()
	}
}
