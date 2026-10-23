//
//  PhotoGridViewModel.swift
//  GrowingUp
//
//  Owns the PhotoKit state machine for the custom photo grid: authorization,
//  asset fetching, thumbnail delivery, single-select working-image loading,
//  and live refresh on library changes (incl. full <-> limited transitions).
//

import Photos
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class PhotoGridViewModel: NSObject {

	private(set) var authState: PhotoAuthState = .notDetermined
	private(set) var assets: [PhotoAsset] = []
	/// True while a tapped asset's working image is being prepared.
	private(set) var isPreparingSelection = false
	/// 0...1 while an iCloud original downloads; drives a determinate bar.
	private(set) var selectionProgress: Double = 0
	/// Set when loading the photo fails; drives a retry alert.
	private(set) var selectionFailed = false

	@ObservationIgnored private let imageManager = PHCachingImageManager()
	@ObservationIgnored private var fetchResult: PHFetchResult<PHAsset>?
	@ObservationIgnored private var registered = false
	@ObservationIgnored private var selectionRequestID: PHImageRequestID?
	@ObservationIgnored private var selectionTask: Task<Void, Never>?
	@ObservationIgnored private let isPreview: Bool

	override init() {
		isPreview = false
		super.init()
	}

	init(previewImages: [UIImage]) {
		authState = .full
		assets = previewImages.map(PhotoAsset.init(previewImage:))
		isPreview = true
		super.init()
	}

	// MARK: - Lifecycle

	func onAppear() async {
		guard !isPreview else { return }
		let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
		if status == .notDetermined {
			let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
			apply(granted)
		} else {
			apply(status)
		}
	}

	private func apply(_ status: PHAuthorizationStatus) {
		authState = PhotoAuthState(status)
		guard authState.showsGrid else {
			assets = []
			return
		}
		registerObserverIfNeeded()
		reloadFetch()
	}

	private func reloadFetch() {
		let options = PHFetchOptions()
		options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		let result = PHAsset.fetchAssets(with: .image, options: options)
		fetchResult = result
		var items: [PhotoAsset] = []
		items.reserveCapacity(result.count)
		result.enumerateObjects { asset, _, _ in items.append(PhotoAsset(asset)) }
		assets = items
	}

	// MARK: - Thumbnails

	/// Requests a grid thumbnail. Resolves on the first available image so the
	/// grid paints quickly; PHCachingImageManager dedupes repeated requests.
	func thumbnail(for asset: PhotoAsset, targetSize: CGSize) async -> UIImage? {
		if let previewImage = asset.previewImage { return previewImage }
		guard let photoAsset = asset.asset else { return nil }
		return await withCheckedContinuation { continuation in
			let options = PHImageRequestOptions()
			// High-quality, exactly-sized renditions so the grid never shows a
			// pixelated degraded placeholder (opportunistic delivers a low-res
			// image first, which the gate would otherwise resolve on and keep).
			options.deliveryMode = .highQualityFormat
			options.resizeMode = .exact
			options.isNetworkAccessAllowed = true
			// The result handler can fire off the main thread for iCloud assets.
			// The gate is a @MainActor box so the single-resume invariant is
			// enforced under actor isolation rather than an unsynchronized flag.
			let gate = ContinuationGate()
			imageManager.requestImage(
				for: photoAsset,
				targetSize: targetSize,
				contentMode: .aspectFill,
				options: options
			) { image, info in
				let isFinal = !((info?[PHImageResultIsDegradedKey] as? Bool) ?? false)
				Task { @MainActor in
					guard gate.finish(when: image != nil || isFinal) else { return }
					continuation.resume(returning: image)
				}
			}
		}
	}

	// MARK: - Single selection -> working image

	func select(_ asset: PhotoAsset, completion: @escaping (UIImage) -> Void) {
		guard !isPreparingSelection else { return }
		if let previewImage = asset.previewImage {
			completion(previewImage)
			return
		}
		guard let photoAsset = asset.asset else { return }
		isPreparingSelection = true
		selectionProgress = 0
		selectionFailed = false
		selectionTask = Task {
			do {
				let (data, orientation) = try await imageData(for: photoAsset)
				let image = try await WorkingImage.decode(data, orientation: orientation)
				try Task.checkCancellation()
				resetSelection()
				completion(image)
			} catch {
				// A selection cancelled by the user was already reset by `cancelSelection`.
				if !Task.isCancelled { failSelection() }
			}
		}
	}

	/// The asset's current image data and the orientation Photos shows it in, downloaded from iCloud when needed.
	private func imageData(for asset: PHAsset) async throws -> (Data, CGImagePropertyOrientation) {
		try Task.checkCancellation()
		let options = PHImageRequestOptions()
		options.isNetworkAccessAllowed = true
		// Called on a background queue while an iCloud original downloads.
		options.progressHandler = { [weak self] progress, _, _, _ in
			Task { @MainActor in
				guard let self, self.isPreparingSelection else { return }
				self.selectionProgress = progress
			}
		}
		// PhotoKit calls the handler exactly once, also when the request is cancelled.
		return try await withCheckedThrowingContinuation { continuation in
			selectionRequestID = imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, orientation, info in
				if let data {
					continuation.resume(returning: (data, orientation))
				} else if (info?[PHImageCancelledKey] as? Bool) ?? false {
					continuation.resume(throwing: CancellationError())
				} else {
					continuation.resume(throwing: info?[PHImageErrorKey] as? Error ?? CocoaError(.fileReadUnknown))
				}
			}
		}
	}

	/// Cancels an in-flight load (e.g. a slow iCloud download) or decode.
	func cancelSelection() {
		selectionTask?.cancel()
		if let id = selectionRequestID {
			imageManager.cancelImageRequest(id)
		}
		resetSelection()
	}

	func dismissError() {
		selectionFailed = false
	}

	private func resetSelection() {
		selectionTask = nil
		selectionRequestID = nil
		isPreparingSelection = false
		selectionProgress = 0
	}

	private func failSelection() {
		resetSelection()
		selectionFailed = true
	}

	// MARK: - Limited library management

	func presentLimitedPicker(from viewController: UIViewController) {
		PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
	}

	// MARK: - Change observation

	private func registerObserverIfNeeded() {
		guard !registered else { return }
		PHPhotoLibrary.shared().register(self)
		registered = true
	}

	deinit {
		if registered {
			PHPhotoLibrary.shared().unregisterChangeObserver(self)
		}
	}
}

extension PhotoGridViewModel: PHPhotoLibraryChangeObserver {
	nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
		Task { @MainActor in
			// Authorization may have flipped (full <-> limited) and/or the
			// permitted asset set may have changed — re-read both.
			apply(PHPhotoLibrary.authorizationStatus(for: .readWrite))
		}
	}
}
