//
//  PhotoGridViewModel.swift
//  GrowingUp
//
//  Owns the PhotoKit state machine for the custom photo grid: authorization,
//  asset fetching, thumbnail delivery, single-select full-resolution loading,
//  and live refresh on library changes (incl. full <-> limited transitions).
//

import Photos
import PhotosUI
import SwiftUI

/// A single photo-library asset, adapted for SwiftUI identity.
struct PhotoAsset: Identifiable, Equatable {
    let asset: PHAsset
    var id: String { asset.localIdentifier }
    init(_ asset: PHAsset) { self.asset = asset }
}

@MainActor
@Observable
final class PhotoGridViewModel: NSObject {

    private(set) var authState: PhotoAuthState = .notDetermined
    private(set) var assets: [PhotoAsset] = []
    /// True while a tapped asset's full-resolution image is being prepared.
    private(set) var isPreparingSelection = false
    /// 0...1 while an iCloud original downloads; drives a determinate bar.
    private(set) var selectionProgress: Double = 0
    /// Set when full-resolution loading fails; drives a retry alert.
    private(set) var selectionFailed = false

    @ObservationIgnored private let imageManager = PHCachingImageManager()
    @ObservationIgnored private var fetchResult: PHFetchResult<PHAsset>?
    @ObservationIgnored private var registered = false
    @ObservationIgnored private var selectionRequestID: PHImageRequestID?

    // MARK: - Lifecycle

    func onAppear() async {
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
        await withCheckedContinuation { continuation in
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
                for: asset.asset,
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

    // MARK: - Single selection -> full resolution

    func select(_ asset: PhotoAsset, completion: @escaping (UIImage) -> Void) {
        isPreparingSelection = true
        selectionProgress = 0
        selectionFailed = false
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        // Called on a background queue while an iCloud original downloads.
        options.progressHandler = { [weak self] progress, error, _, _ in
            Task { @MainActor in
                guard let self, self.isPreparingSelection else { return }
                self.selectionProgress = progress
                if error != nil { self.failSelection() }
            }
        }
        selectionRequestID = imageManager.requestImage(
            for: asset.asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .default,
            options: options
        ) { [weak self] image, info in
            guard let self else { return }
            // Cancelled by the user: state is already reset; ignore the callback.
            if (info?[PHImageCancelledKey] as? Bool) ?? false { return }
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if let image, !degraded {
                self.selectionRequestID = nil
                self.isPreparingSelection = false
                self.selectionProgress = 0
                completion(image)
            } else if info?[PHImageErrorKey] != nil || (image == nil && !degraded) {
                // Final delivery with no image, or an explicit error -> surface it.
                self.failSelection()
            }
            // A degraded placeholder with more to come: keep waiting.
        }
    }

    /// Cancels an in-flight full-resolution load (e.g. a slow iCloud download).
    func cancelSelection() {
        if let id = selectionRequestID {
            imageManager.cancelImageRequest(id)
            selectionRequestID = nil
        }
        isPreparingSelection = false
        selectionProgress = 0
    }

    func dismissError() {
        selectionFailed = false
    }

    private func failSelection() {
        selectionRequestID = nil
        isPreparingSelection = false
        selectionProgress = 0
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
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

/// One-shot, @MainActor-isolated gate guarding a single `continuation.resume`
/// against PhotoKit's potentially repeated opportunistic callbacks.
@MainActor
private final class ContinuationGate {
    private var finished = false

    /// Returns true exactly once — the first time it is called with `shouldFinish`
    /// true — and false on every later call, so the caller resumes only once.
    func finish(when shouldFinish: Bool) -> Bool {
        guard shouldFinish, !finished else { return false }
        finished = true
        return true
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
