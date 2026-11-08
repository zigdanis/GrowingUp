import Foundation

/// The earlier libraries store recovery set aside next to the active store, and the one way to take one out of the app:
/// an exported archive. It only ever adds to a preserved folder (its note and links to its photos); nothing here moves,
/// changes or deletes a preserved file or a loose photo, except the explicit deletion of a whole preserved store.
public struct PreservedStoreLibrary: PreservedStoreGateway {
	/// The active store; preserved folders are its siblings, named `<store>.backup-<timestamp>-<UUID>`.
	let storeURL: URL
	/// Where the app keeps every person's photo files, as `<UUID>.png`, `.jpg` or `.heic`: the loose photos.
	let photosDirectory: URL
	/// Where exports are written; each export replaces the ones before it.
	let exportsDirectory: URL

	/// The App Group's store and photos, as the app and the widget use them.
	public static func shared() throws -> PreservedStoreLibrary {
		let appGroup = try CoreDataStackImplementation.appGroupDirectory()
		return PreservedStoreLibrary(
			storeURL: CoreDataStackImplementation.storeURL(in: appGroup), photosDirectory: appGroup,
			exportsDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("PreservedExports", isDirectory: true))
	}

	static let photosFolderName = "Photos"

	/// Every preserved store, newest first. A folder holds one only once its main SQLite file is in it; a move still in
	/// progress, which its journal names, is left to the next store load to finish.
	public func stores() throws -> [PreservedStore] {
		let parent = storeURL.deletingLastPathComponent()
		let names: [String]
		do {
			names = try FileManager.default.contentsOfDirectory(atPath: parent.path)
		} catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
			return []
		}
		let pending = (try? Data(contentsOf: storeURL.appendingPathExtension("recovery"))).flatMap { String(data: $0, encoding: .utf8) }
		let prefix = storeURL.lastPathComponent + ".backup-"
		return try names.filter { $0.hasPrefix(prefix) && $0 != pending }.compactMap { name in
			let folder = parent.appendingPathComponent(name, isDirectory: true)
			guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(storeURL.lastPathComponent).path) else { return nil }
			return try store(in: folder)
		}
		.sorted { ($0.preservedAt, $0.id) > ($1.preservedAt, $1.id) }
	}

	/// Keeps the photo files `store` may refer to inside its folder, once; see `keepPhotos(from:in:)`. Store recovery
	/// does this as it sets a store aside; this covers stores set aside by earlier versions of the app.
	public func preservePhotos(of store: PreservedStore) throws -> PreservedStore {
		let folder = folder(of: store)
		return try SQLiteStoreAccess.coordinate(at: storeURL) { _ in
			if try manifest(in: folder).photosPreservedAt == nil {
				try Self.keepPhotos(from: photosDirectory, in: folder, manifest: manifest(in: folder))
			}
			return try self.store(in: folder)
		}
	}

	/// Links every loose photo file in `photosDirectory` into the preserved `folder`'s `Photos` folder (copies where a
	/// link is impossible), so removing a person's photo from the active library never takes it from the preserved store,
	/// and notes the pass done. The preserved database can't be read, so every photo counts: at recovery the new store is
	/// empty, and for a store set aside earlier, a later person's photo in its copy costs nothing but a link. A pass that
	/// was interrupted resumes. The caller holds the `SQLiteStoreAccess` claim.
	static func keepPhotos(from photosDirectory: URL, in folder: URL, manifest: PreservedStoreManifest) throws {
		var manifest = manifest
		let photos = folder.appendingPathComponent(photosFolderName, isDirectory: true)
		try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
		for source in try loosePhotos(in: photosDirectory) {
			let destination = photos.appendingPathComponent(source.lastPathComponent)
			if !FileManager.default.fileExists(atPath: destination.path) {
				try FileManager.default.linkOrCopyItem(at: source, to: destination)
			}
		}
		// With those an interrupted pass kept, whose loose source may have gone since.
		manifest.photoFileNames = try FileManager.default.contentsOfDirectory(atPath: photos.path).filter(PhotoFileName.isPhoto).sorted()
		manifest.photosPreservedAt = Date()
		try manifest.write(in: folder)
	}

	/// Notes that the app reported `store`'s recovery, so a later launch does not report it again.
	public func markReported(_ store: PreservedStore) throws -> PreservedStore {
		let folder = folder(of: store)
		return try SQLiteStoreAccess.coordinate(at: storeURL) { _ in
			var manifest = try manifest(in: folder)
			guard manifest.reportedAt == nil else { return try self.store(in: folder) }
			manifest.reportedAt = Date()
			try manifest.write(in: folder)
			return try self.store(in: folder)
		}
	}

	/// Writes `store` as one zip archive: its SQLite files exactly as preserved, its photos, a `manifest.json` with each
	/// file's size and SHA-256, and a README. The photos are those kept with it, and until its photos pass is done, the
	/// loose ones too. Everything is staged under the same claim as store loads, so a recovery being finished cannot
	/// split the SQLite files. Nothing is sent anywhere; a failure leaves no partial archive behind and never touches the
	/// preserved files.
	public func export(_ store: PreservedStore, now: Date = Date()) throws -> URL {
		let folder = folder(of: store)
		let archiver = PreservedStoreArchiver(storeFileName: storeURL.lastPathComponent)
		try? FileManager.default.removeItem(at: exportsDirectory)
		try FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
		let staging = try SQLiteStoreAccess.coordinate(at: storeURL) { _ in
			try archiver.stage(
				store: try self.store(in: folder), folder: folder, photos: exportedPhotos(in: folder), exportedAt: now, in: exportsDirectory)
		}
		defer { try? FileManager.default.removeItem(at: staging.deletingLastPathComponent()) }
		return try archiver.compress(staging, into: exportsDirectory)
	}

	/// The photos an export of the store in `folder` holds: those kept with it, and until its photos pass is done, the
	/// loose ones too, of which a kept copy wins.
	func exportedPhotos(in folder: URL) throws -> [URL] {
		var photos: [String: URL] = [:]
		if try manifest(in: folder).photosPreservedAt == nil {
			for url in try Self.loosePhotos(in: photosDirectory) { photos[url.lastPathComponent] = url }
		}
		let kept = folder.appendingPathComponent(Self.photosFolderName, isDirectory: true)
		if FileManager.default.fileExists(atPath: kept.path) {
			for url in try Self.loosePhotos(in: kept) { photos[url.lastPathComponent] = url }
		}
		return photos.values.sorted { $0.lastPathComponent < $1.lastPathComponent }
	}

	/// Deletes `store`'s folder, which only an explicit, confirmed request does, and never while a recovery's journal
	/// names it. Loose photo files stay: the active
	/// library or another preserved store may still need them, and nothing can tell for certain that they don't.
	public func delete(_ store: PreservedStore) throws {
		let folder = folder(of: store)
		guard store.id.hasPrefix(storeURL.lastPathComponent + ".backup-"), !store.id.contains("/") else {
			throw CocoaError(.fileNoSuchFile)
		}
		try SQLiteStoreAccess.coordinate(at: storeURL) { _ in
			// A recovery still moving files into the folder resumes on the next load; without the folder it couldn't.
			let pending = (try? Data(contentsOf: storeURL.appendingPathExtension("recovery"))).flatMap { String(data: $0, encoding: .utf8) }
			guard pending != store.id else { throw CocoaError(.fileWriteNoPermission) }
			try FileManager.default.removeItem(at: folder)
		}
	}

	/// Removes the archives `export` wrote, as when the share sheet closes.
	public func removeExports() {
		try? FileManager.default.removeItem(at: exportsDirectory)
	}

	private func folder(of store: PreservedStore) -> URL {
		storeURL.deletingLastPathComponent().appendingPathComponent(store.id, isDirectory: true)
	}

	private func store(in folder: URL) throws -> PreservedStore {
		let manifest = try manifest(in: folder)
		return PreservedStore(
			id: folder.lastPathComponent, preservedAt: manifest.preservedAt, cause: manifest.preservedCause,
			appVersion: manifest.appVersion, hasPreservedPhotos: manifest.photosPreservedAt != nil,
			isReported: manifest.reportedAt != nil, byteCount: Self.byteCount(of: folder))
	}

	private static func byteCount(of folder: URL) -> Int64 {
		let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
		var total: Int64 = 0
		while let url = files?.nextObject() as? URL {
			guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { continue }
			total += Int64(values.fileSize ?? 0)
		}
		return total
	}

	/// The folder's note, or for a folder an earlier version set aside, one with the date its name records.
	private func manifest(in folder: URL) throws -> PreservedStoreManifest {
		if let manifest = try? PreservedStoreManifest.read(in: folder) { return manifest }
		let date = Self.date(inFolderName: folder.lastPathComponent, storeName: storeURL.lastPathComponent)
		let created = (try? FileManager.default.attributesOfItem(atPath: folder.path)[.creationDate]) as? Date
		return PreservedStoreManifest(preservedAt: date ?? created ?? Date(timeIntervalSince1970: 0), cause: .unknown, appVersion: nil, process: nil)
	}

	private static func loosePhotos(in directory: URL) throws -> [URL] {
		try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
			.filter { PhotoFileName.isPhoto($0.lastPathComponent) }
	}

	/// The timestamp `SQLiteStoreBackup` puts in a folder's name: ISO 8601 with dashes for colons.
	static func date(inFolderName name: String, storeName: String) -> Date? {
		let stamp = name.dropFirst(storeName.count + ".backup-".count).prefix("yyyy-MM-ddTHH-mm-ssZ".count)
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(identifier: "UTC")
		formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
		return formatter.date(from: String(stamp))
	}
}
