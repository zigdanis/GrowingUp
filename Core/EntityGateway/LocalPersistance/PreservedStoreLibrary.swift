import Foundation

/// The earlier libraries store recovery set aside next to the active store, and the one way to take one out of the app:
/// an exported archive. It only ever adds to a preserved folder (its note and links to its photos); nothing here moves,
/// changes or deletes a preserved file or one the active library uses.
public struct PreservedStoreLibrary: PreservedStoreGateway {
	/// The active store; preserved folders are its siblings, named `<store>.backup-<timestamp>-<UUID>`.
	let storeURL: URL
	/// Where the app keeps every person's photo files, as `<UUID>.png`, `.jpg` or `.heic`.
	let photosDirectory: URL
	/// Where exports are written; each export replaces the ones before it.
	let exportsDirectory: URL

	init(storeURL: URL, photosDirectory: URL, exportsDirectory: URL) {
		self.storeURL = storeURL
		self.photosDirectory = photosDirectory
		self.exportsDirectory = exportsDirectory
	}

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

	/// Keeps the photo files `store` may refer to inside its folder, as hard links (copies where a link is impossible),
	/// so deleting a person from the active library, which removes their photo files, never takes them from the preserved
	/// store. The preserved database can't be read, so they are every photo file the active library does not use,
	/// `activePhotoIDs`. Done once per store: later photos belong to the active library. An interrupted pass resumes.
	public func preservePhotos(of store: PreservedStore, activePhotoIDs: Set<UUID>) throws -> PreservedStore {
		let folder = folder(of: store)
		return try SQLiteStoreAccess.coordinate(at: storeURL) { _ in
			var manifest = try manifest(in: folder)
			guard manifest.photosPreservedAt == nil else { return try self.store(in: folder) }
			let photos = folder.appendingPathComponent(Self.photosFolderName, isDirectory: true)
			try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
			var names: [String] = []
			for source in try loosePhotos(excluding: activePhotoIDs) {
				let destination = photos.appendingPathComponent(source.lastPathComponent)
				if !FileManager.default.fileExists(atPath: destination.path) {
					try FileManager.default.linkOrCopyItem(at: source, to: destination)
				}
				names.append(source.lastPathComponent)
			}
			// Kept from an interrupted pass whose source has gone since.
			let kept = try FileManager.default.contentsOfDirectory(atPath: photos.path).filter(PhotoFileName.isPhoto)
			manifest.photoFileNames = Set(names + kept).sorted()
			manifest.photosPreservedAt = Date()
			try manifest.write(in: folder)
			return try self.store(in: folder)
		}
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
	/// file's size and SHA-256, and a README. The SQLite files are staged under the same claim as store loads, so a
	/// recovery being finished cannot split them. Nothing is sent anywhere; a failure leaves no partial archive behind
	/// and never touches the preserved files.
	public func export(_ store: PreservedStore, activePhotoIDs: Set<UUID>, now: Date = Date()) throws -> URL {
		let folder = folder(of: store)
		let archiver = PreservedStoreArchiver(storeFileName: storeURL.lastPathComponent)
		try? FileManager.default.removeItem(at: exportsDirectory)
		try FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
		let staging = try SQLiteStoreAccess.coordinate(at: storeURL) { _ in
			let photos =
				store.hasPreservedPhotos
				? try FileManager.default.contentsOfDirectory(
					at: folder.appendingPathComponent(Self.photosFolderName, isDirectory: true), includingPropertiesForKeys: nil
				).filter { PhotoFileName.isPhoto($0.lastPathComponent) }
				: try loosePhotos(excluding: activePhotoIDs)
			return try archiver.stage(store: store, folder: folder, photos: photos, exportedAt: now, in: exportsDirectory)
		}
		defer { try? FileManager.default.removeItem(at: staging.deletingLastPathComponent()) }
		return try archiver.compress(staging, into: exportsDirectory)
	}

	/// Deletes `store`'s folder, which only an explicit, confirmed request does. The loose photo files it kept, which the
	/// active library does not use, go too: they belonged only to it. Another preserved store that shares one keeps its
	/// own link to it. Without `activePhotoIDs`, as before the people loaded, or while another preserved store's photos
	/// are not kept with it yet, every loose file stays.
	public func delete(_ store: PreservedStore, activePhotoIDs: Set<UUID>?) throws {
		let folder = folder(of: store)
		guard store.id.hasPrefix(storeURL.lastPathComponent + ".backup-"), !store.id.contains("/") else {
			throw CocoaError(.fileNoSuchFile)
		}
		try SQLiteStoreAccess.coordinate(at: storeURL) { _ in
			let kept = (try? PreservedStoreManifest.read(in: folder))?.photoFileNames ?? []
			// A store whose photos are not kept with it yet still relies on the loose files.
			let othersRely = try stores().contains { $0.id != store.id && !$0.hasPreservedPhotos }
			try FileManager.default.removeItem(at: folder)
			guard let activePhotoIDs, !othersRely else { return }
			for name in kept {
				guard let id = PhotoFileName.id(of: name), !activePhotoIDs.contains(id) else { continue }
				try? FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(name))
			}
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

	private func loosePhotos(excluding activePhotoIDs: Set<UUID>) throws -> [URL] {
		try FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil).filter { url in
			guard let id = PhotoFileName.id(of: url.lastPathComponent) else { return false }
			return !activePhotoIDs.contains(id)
		}
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
