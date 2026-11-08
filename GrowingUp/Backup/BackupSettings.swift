import Foundation

/// The iCloud backup's own preferences, kept apart from the app's: whether it is on, this install's folder, what was last
/// written there and for which iCloud account. They live in UserDefaults, never in the Keychain: they go with the app, so
/// a reinstall writes a new folder and leaves the old one to restore from.
final class BackupSettings {
	private let defaults: UserDefaults
	private let prefix: String

	/// - Parameters:
	///   - prefix: Keeps the Debug local-folder backup apart from the real one.
	///   - deviceID: This device's `identifierForVendor`. UserDefaults move to a new iPhone with Quick Start or a device
	///     backup, and two devices in use must not share one folder, so a different device starts its own. Nil, as before
	///     the first unlock, changes nothing.
	init(defaults: UserDefaults = .standard, prefix: String = "iCloudBackup.", deviceID: String? = nil) {
		self.defaults = defaults
		self.prefix = prefix
		guard let deviceID else { return }
		let deviceKey = prefix + "writerDevice"
		if let stored = defaults.string(forKey: deviceKey), stored != deviceID {
			for key in ["writerID", "lastContentHash", "lastBackupAt", "accountIdentity"] {
				defaults.removeObject(forKey: prefix + key)
			}
		}
		defaults.set(deviceID, forKey: deviceKey)
	}

	var isEnabled: Bool {
		get { defaults.object(forKey: prefix + "enabled") as? Bool ?? true }
		set { defaults.set(newValue, forKey: prefix + "enabled") }
	}

	/// This install's backup folder; see `init` for when it changes.
	var writerID: UUID {
		if let stored = defaults.string(forKey: prefix + "writerID").flatMap(UUID.init(uuidString:)) { return stored }
		let id = UUID()
		defaults.set(id.uuidString, forKey: prefix + "writerID")
		return id
	}

	var lastBackupAt: Date? {
		get { defaults.object(forKey: prefix + "lastBackupAt") as? Date }
		set { defaults.set(newValue, forKey: prefix + "lastBackupAt") }
	}

	/// `BackupCodec.contentHash(of:)` of the last backup written.
	var lastContentHash: String? {
		get { defaults.string(forKey: prefix + "lastContentHash") }
		set { defaults.set(newValue, forKey: prefix + "lastContentHash") }
	}

	/// The archived `ubiquityIdentityToken` the last backup was written for.
	var accountIdentity: Data? {
		get { defaults.data(forKey: prefix + "accountIdentity") }
		set { defaults.set(newValue, forKey: prefix + "accountIdentity") }
	}

	/// The person chose "Not now" on the empty mosaic's restore offer; Settings still lists every backup.
	var isRestoreOfferDismissed: Bool {
		get { defaults.bool(forKey: prefix + "restoreOfferDismissed") }
		set { defaults.set(newValue, forKey: prefix + "restoreOfferDismissed") }
	}

	/// Forgets the last backup, so the next change writes a whole one again.
	func forgetLastBackup() {
		lastContentHash = nil
		lastBackupAt = nil
	}

	/// Notes the iCloud account the app now uses and, when it differs from the one the last backup was written for, as
	/// after signing into another account while the app was not running, forgets that backup. Returns whether it did.
	@discardableResult
	func noteAccount(_ identity: NSObject?) -> Bool {
		guard let identity, let archived = try? NSKeyedArchiver.archivedData(withRootObject: identity, requiringSecureCoding: true)
		else { return false }
		defer { accountIdentity = archived }
		guard let stored = accountIdentity, stored != archived else { return false }
		// Apple compares tokens with isEqual; differing archives of an equal token change nothing.
		if let previous = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSObject.self], from: stored)) as? NSObject,
			previous.isEqual(identity)
		{
			return false
		}
		forgetLastBackup()
		return true
	}
}
