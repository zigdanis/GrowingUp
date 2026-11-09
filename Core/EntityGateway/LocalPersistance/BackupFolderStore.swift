import Foundation

/// The backups of every install of the app, one `BackupFolder` each, named by the install's UUID:
/// `<root>/<install>/backup.json`, `backup-previous.json` and `photos/<sha256>.<ext>`.
///
/// In the app the root is `Backups` at the top of the app's iCloud container, outside its `Documents`, so iCloud keeps it
/// with the person's account but iCloud Drive and Files never show it. Each install writes only its own folder, so two
/// devices, or a reinstall, never write the same file, and a reinstalled app never overwrites the backup it should
/// restore. Anything in the root that is not an install's folder is no backup and is left alone.
public struct BackupFolderStore: Sendable {
	public static let rootFolderName = "Backups"

	public let root: URL
	public let access: BackupFileAccess

	public init(root: URL, access: BackupFileAccess) {
		self.root = root
		self.access = access
	}

	/// The folder this install writes.
	public func folder(for install: UUID) -> BackupFolder {
		BackupFolder(url: root.appendingPathComponent(install.uuidString, isDirectory: true), access: access)
	}

	/// Every backup there is to restore, newest first: each install's latest copy, and its previous copy as well when the
	/// latest is empty or can't be restored whole and the previous one is complete. `knownFolders` adds the folders iCloud
	/// reported whose files may not be on this device yet; reading them downloads them.
	public func candidates(thisInstall: UUID, knownFolders: Set<String> = []) -> [BackupCandidate] {
		let names = Set(access.names(in: root)).union(knownFolders).filter(Self.isInstallFolder)
		return names.flatMap { name -> [BackupCandidate] in
			let folder = folder(named: name)
			guard let latest = try? folder.document() else { return [] }
			let isThisDevice = UUID(uuidString: name) == thisInstall
			var found = [BackupCandidate(folderName: name, document: latest, isThisDevice: isThisDevice)]
			if latest.isEmpty || !folder.isComplete(latest), let earlier = previousCandidate(folderName: name, thisInstall: thisInstall),
				earlier.createdAt != latest.createdAt
			{
				found.append(earlier)
			}
			return found
		}
		.sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
	}

	/// The previous copy of the install in `folderName` when it is complete and not empty, as the list offers after the
	/// latest copy failed to load, such as with a damaged photo only loading finds.
	public func previousCandidate(folderName: String, thisInstall: UUID) -> BackupCandidate? {
		guard Self.isInstallFolder(folderName) else { return nil }
		let folder = folder(named: folderName)
		guard let previous = try? folder.document(previous: true), !previous.isEmpty, folder.isComplete(previous) else { return nil }
		return BackupCandidate(
			folderName: folderName, document: previous, isThisDevice: UUID(uuidString: folderName) == thisInstall, isPreviousCopy: true)
	}

	/// The backup `candidate` stands for, with every photo checked and copied into `stagingDirectory`.
	public func load(_ candidate: BackupCandidate, stagingDirectory: URL) throws -> LoadedBackup {
		guard Self.isInstallFolder(candidate.folderName) else { throw BackupError.notABackup }
		return try folder(named: candidate.folderName).load(previous: candidate.isPreviousCopy, stagingDirectory: stagingDirectory)
	}

	/// Removes the install's whole backup from iCloud, or only its previous copy.
	public func delete(_ candidate: BackupCandidate) throws {
		guard Self.isInstallFolder(candidate.folderName) else { throw CocoaError(.fileWriteInvalidFileName) }
		try folder(named: candidate.folderName).remove(previousOnly: candidate.isPreviousCopy)
	}

	/// Install folders are UUIDs; anything else in the root is not a backup.
	public static func isInstallFolder(_ name: String) -> Bool {
		UUID(uuidString: name) != nil
	}

	private func folder(named name: String) -> BackupFolder {
		BackupFolder(url: root.appendingPathComponent(name, isDirectory: true), access: access)
	}
}
