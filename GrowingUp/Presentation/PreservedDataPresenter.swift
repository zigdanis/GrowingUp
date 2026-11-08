import Core
import Foundation
import Observation

/// The earlier libraries store recovery set aside, which the app keeps visible until the person no longer needs the
/// notice, and their export. Store recovery may run in the widget's process, so the app learns of it from the files a
/// recovery leaves, whenever it refreshes: after the people load and on each return to the foreground.
///
/// Keeping or deleting photo files must leave the active library's alone, so each call takes the people the active
/// library holds, or nil unless they loaded successfully, in which case no loose photo is kept or deleted.
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

	/// Reads the preserved stores again. With the active library's people, it also keeps each store's photos with it,
	/// which needs to know the photos the active library uses, and reports each new recovery once, with only its cause's
	/// category. Refreshes run one after another, so none reports a store twice.
	func refresh(people: [Person]?) async {
		guard gateway != nil else { return }
		let activePhotoIDs = people.map(Self.photoIDs)
		let previous = refreshing
		let refresh = Task { [weak self] in
			await previous?.value
			await self?.performRefresh(activePhotoIDs: activePhotoIDs)
		}
		refreshing = refresh
		await refresh.value
	}

	private func performRefresh(activePhotoIDs: Set<UUID>?) async {
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
				if let activePhotoIDs, !store.hasPreservedPhotos {
					do {
						stores[index] = try gateway.preservePhotos(of: store, activePhotoIDs: activePhotoIDs)
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
	/// A store whose photos are not kept with it yet exports the loose photos the active library does not use.
	func startExport(_ store: PreservedStore, people: [Person]?) async {
		guard let gateway, export != .preparing else { return }
		gateway.removeExports()
		export = .preparing
		let activePhotoIDs = people.map(Self.photoIDs) ?? []
		let result = await Task.detached(priority: .userInitiated) {
			Result { try gateway.export(store, activePhotoIDs: activePhotoIDs, now: Date()) }
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

	/// Deletes `store` for good, which the person confirmed; see `PreservedStoreGateway.delete(_:activePhotoIDs:)`.
	func delete(_ store: PreservedStore, people: [Person]?) async {
		guard let gateway, !isDeleting else { return }
		isDeleting = true
		defer { isDeleting = false }
		let activePhotoIDs = people.map(Self.photoIDs)
		let result = await Task.detached(priority: .userInitiated) {
			Result { try gateway.delete(store, activePhotoIDs: activePhotoIDs) }
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

	static func photoIDs(of people: [Person]) -> Set<UUID> {
		Set(people.flatMap { [$0.appPicId, $0.widgetPicId, $0.originalPicId].compactMap { $0 } })
	}
}
