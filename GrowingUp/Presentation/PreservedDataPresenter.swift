import Core
import Foundation
import Observation

/// The earlier libraries store recovery set aside, which the app keeps visible until the person no longer needs the
/// notice, and their export. Store recovery may run in the widget's process, so the app learns of it from the files a
/// recovery leaves, whenever it refreshes: after every load of the people, at launch, on Try Again and on each return to
/// the foreground.
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
	/// The latest refresh or deletion; each waits for the one before, so a refresh never republishes a deleted copy and
	/// none reports a store twice.
	@ObservationIgnored private var lastStep: Task<Void, Never>?
	/// Counts exports, so one the sheet abandoned while it was written cleans up instead of opening the share sheet.
	@ObservationIgnored private var exportGeneration = 0

	init(gateway: PreservedStoreGateway?, analytics: AnalyticsGateway) {
		self.gateway = gateway
		self.analytics = analytics
	}

	var newest: PreservedStore? { stores.first }

	/// Reads the preserved stores again, keeps the photos of one an earlier version set aside with it, and reports each
	/// new recovery once, with only its cause's category. A failed read keeps the stores already shown.
	func refresh() async {
		guard gateway != nil else { return }
		await inTurn { await $0.performRefresh() }
	}

	/// Runs `step` after every refresh and deletion before it.
	private func inTurn(_ step: @escaping @MainActor (PreservedDataPresenter) async -> Void) async {
		let previous = lastStep
		let next = Task { [weak self] in
			await previous?.value
			guard let self else { return }
			await step(self)
		}
		lastStep = next
		await next.value
	}

	private func performRefresh() async {
		guard let gateway else { return }
		let read = await Task.detached(priority: .utility) { () -> Result<([PreservedStore], [AnalyticsFailure]), Error> in
			Result {
				var stores = try gateway.stores()
				var failures: [AnalyticsFailure] = []
				for (index, store) in stores.enumerated() where !store.hasPreservedPhotos {
					do {
						stores[index] = try gateway.preservePhotos(of: store)
					} catch {
						failures.append(AnalyticsFailure(operation: "preserve_photos", error: error))
					}
				}
				return (stores, failures)
			}
		}.value
		switch read {
		case .success(let (stores, failures)):
			self.stores = stores
			for failure in failures { analytics.report(failure) }
		case .failure(let error):
			analytics.report(AnalyticsFailure(operation: "read_preserved_data", error: error))
			return
		}
		// Reported before it is noted: a note that fails to save, or never gets saved, reports it again next time.
		let unreported = stores.filter { !$0.isReported }
		for store in unreported {
			analytics.report(AnalyticsFailure(operation: "recover_store", error: store.cause.reportedError))
		}
		guard !unreported.isEmpty else { return }
		let noted = await Task.detached(priority: .utility) { unreported.compactMap { try? gateway.markReported($0) } }.value
		for store in noted {
			if let index = stores.firstIndex(where: { $0.id == store.id }) { stores[index] = store }
		}
	}

	/// Writes `store` as an archive for the share sheet. Nothing is sent: only the person's choice in the sheet moves it.
	func startExport(_ store: PreservedStore) async {
		guard let gateway, export != .preparing else { return }
		gateway.removeExports()
		export = .preparing
		exportGeneration += 1
		let generation = exportGeneration
		let result = await Task.detached(priority: .userInitiated) {
			Result { try gateway.export(store, now: Date()) }
		}.value
		guard generation == exportGeneration else {
			// The sheet closed meanwhile: nothing opens the archive, so it goes.
			gateway.removeExports()
			export = .idle
			return
		}
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

	/// Deletes `store` for good, which the person confirmed. It waits for a refresh under way, which then cannot show the
	/// deleted copy again.
	func delete(_ store: PreservedStore) async {
		guard let gateway, !isDeleting else { return }
		isDeleting = true
		await inTurn { presenter in
			let result = await Task.detached(priority: .userInitiated) {
				Result { try gateway.delete(store) }
			}.value
			switch result {
			case .success:
				presenter.stores.removeAll { $0.id == store.id }
			case .failure(let error):
				presenter.failure = .delete
				presenter.analytics.report(AnalyticsFailure(operation: "delete_preserved_data", error: error))
			}
		}
		isDeleting = false
	}

	/// Forgets the archive once the share sheet closed, and removes it from the device's temporary files.
	func finishExport() {
		guard export != .preparing else { return }
		export = .idle
		gateway?.removeExports()
	}

	/// Drops the export when its sheet closes: a finished archive goes now, one still being written as soon as it is done.
	/// Until then the export stays preparing, so a new one cannot start into the folder that cleanup empties.
	func abandonExport() {
		exportGeneration += 1
		guard export != .preparing else { return }
		export = .idle
		gateway?.removeExports()
	}
}
