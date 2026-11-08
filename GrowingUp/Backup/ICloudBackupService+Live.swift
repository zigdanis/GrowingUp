import Core
import Foundation
import UIKit

extension ICloudBackupService {
	/// The app's iCloud container, as the entitlements name it.
	nonisolated static let containerIdentifier = "iCloud.pro.ziganshin.GrowingUp"

	/// The backup a real launch keeps in the app's iCloud container. The folder sits outside the container's
	/// `Documents`, so iCloud Drive and Files never list it.
	///
	/// In Debug, `GROWINGUP_BACKUP=local` backs up to `Application Support/DebugBackups` on the device instead, so the
	/// backup screens can be walked on a simulator without an iCloud account; `GROWINGUP_BACKUP=local-new-install` also
	/// gives every launch a new install folder, so backups of earlier launches show as another device's, ready to restore.
	static func live(
		gateway: PeopleBackupGateway, analytics: AnalyticsGateway,
		environment: [String: String] = ProcessInfo.processInfo.environment
	) -> ICloudBackupService {
		#if DEBUG
			if let mode = environment["GROWINGUP_BACKUP"], mode == "local" || mode == "local-new-install" {
				return local(gateway: gateway, analytics: analytics, isNewInstall: mode == "local-new-install")
			}
		#endif
		return ICloudBackupService(
			settings: BackupSettings(deviceID: UIDevice.current.identifierForVendor?.uuidString), gateway: gateway,
			analytics: analytics, observesAccountChanges: true,
			locateStore: {
				await Task.detached(priority: .utility) {
					// Apple asks for this call off the main thread: it can take a while the first time.
					guard let container = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
						return nil
					}
					return BackupFolderStore(
						root: container.appendingPathComponent(BackupFolderStore.rootFolderName, isDirectory: true), access: .iCloud)
				}.value
			},
			discoverFolders: { await ICloudBackupDiscovery.installFolders() },
			accountIdentity: { FileManager.default.ubiquityIdentityToken as? NSObject })
	}

	#if DEBUG
		private static func local(gateway: PeopleBackupGateway, analytics: AnalyticsGateway, isNewInstall: Bool) -> ICloudBackupService {
			let settings: BackupSettings
			if isNewInstall {
				let suite = "pro.ziganshin.GrowingUp.debug-backup-new-install"
				let defaults = UserDefaults(suiteName: suite) ?? .standard
				defaults.removePersistentDomain(forName: suite)
				settings = BackupSettings(defaults: defaults, prefix: "debugBackup.")
			} else {
				settings = BackupSettings(prefix: "debugBackup.", deviceID: UIDevice.current.identifierForVendor?.uuidString)
			}
			let root = URL.applicationSupportDirectory.appendingPathComponent("DebugBackups", isDirectory: true)
			return ICloudBackupService(
				settings: settings, gateway: gateway, analytics: analytics,
				locateStore: { BackupFolderStore(root: root, access: .local) })
		}
	#endif
}
