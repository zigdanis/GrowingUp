import Core
import Foundation

/// Asks iCloud which install folders hold a backup, including ones whose files are not on this device yet: after a
/// reinstall, listing the folder alone misses those.
@MainActor
enum ICloudBackupDiscovery {
	static func installFolders(timeout: Duration = .seconds(10)) async -> Set<String> {
		let query = NSMetadataQuery()
		query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
		query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, BackupFolder.documentName)
		return await withCheckedContinuation { continuation in
			var observer: NSObjectProtocol?
			var isFinished = false
			let finish = {
				guard !isFinished else { return }
				isFinished = true
				query.disableUpdates()
				let folders = (query.results as? [NSMetadataItem] ?? []).compactMap { item -> String? in
					guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
					let folder = url.deletingLastPathComponent()
					guard folder.deletingLastPathComponent().lastPathComponent == BackupFolderStore.rootFolderName else { return nil }
					return folder.lastPathComponent
				}
				query.stop()
				if let observer { NotificationCenter.default.removeObserver(observer) }
				continuation.resume(returning: Set(folders).filter(BackupFolderStore.isInstallFolder))
			}
			observer = NotificationCenter.default.addObserver(
				forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
			) { _ in
				MainActor.assumeIsolated { finish() }
			}
			guard query.start() else {
				finish()
				return
			}
			Task { @MainActor in
				try? await Task.sleep(for: timeout)
				finish()
			}
		}
	}
}
