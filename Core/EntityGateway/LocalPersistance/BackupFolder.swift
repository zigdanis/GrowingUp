import Foundation

/// One backup as a folder: `backup.json` with the `BackupDocument`, and `photos/` with each photo file it lists, named by
/// its SHA-256 (see `BackupCodec.photoFile(digest:name:)`). An exported archive holds the same layout.
///
/// A folder written again keeps the complete copy it replaces as `backup-previous.json`, whose photos stay too, so a
/// bad write never leaves it without a good copy. Photo files are shared by both copies, and those neither refers to go.
public struct BackupFolder: Sendable {
	public static let documentName = "backup.json"
	public static let previousDocumentName = "backup-previous.json"
	public static let photosFolderName = "photos"

	public let url: URL
	public let access: BackupFileAccess

	public init(url: URL, access: BackupFileAccess = .local) {
		self.url = url
		self.access = access
	}

	private var documentURL: URL { url.appendingPathComponent(Self.documentName) }
	private var previousURL: URL { url.appendingPathComponent(Self.previousDocumentName) }
	private var photosURL: URL { url.appendingPathComponent(Self.photosFolderName, isDirectory: true) }

	// MARK: - Writing

	/// Writes `snapshot` as the folder's backup: the photos first and the document last, so the document never names a
	/// photo that is not there. A photo file already in the folder stays when its bytes still match the SHA-256 its name
	/// records, and is written again when they don't. The backup it replaces becomes the previous copy when it is complete; otherwise
	/// the previous copy stays as it was.
	public func write(_ snapshot: LibrarySnapshot) throws {
		try FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
		for photo in snapshot.document.photos where !holds(photo) {
			guard let source = snapshot.photoSources[photo.file] else { throw CocoaError(.fileNoSuchFile) }
			try access.copy(source, to: photosURL.appendingPathComponent(photo.file))
		}
		var kept: Set<String>? = Set(snapshot.document.photos.map(\.file))
		if let current = try? readDocument(at: documentURL), isComplete(current.document) {
			try access.write(current.data, to: previousURL)
			kept?.formUnion(current.document.photos.map(\.file))
		} else if access.exists(previousURL) {
			// A previous copy that can't be read now, as one iCloud has yet to download, keeps every photo.
			let previous = try? readDocument(at: previousURL).document
			kept = previous.flatMap { kept?.union($0.photos.map(\.file)) }
		}
		try access.write(BackupCodec.encode(snapshot.document), to: documentURL)
		guard let kept else { return }
		for name in access.names(in: photosURL) where BackupCodec.isPhotoFile(name) && !kept.contains(name) {
			try? access.delete(photosURL.appendingPathComponent(name))
		}
	}

	/// Removes the whole backup, or only its previous copy; the photos only that copy refers to stay until the next write.
	public func remove(previousOnly: Bool = false) throws {
		try access.delete(previousOnly ? previousURL : url)
	}

	// MARK: - Reading

	/// Whether the folder holds a backup, downloaded or not.
	public var hasDocument: Bool { access.exists(documentURL) }

	/// Whether the latest backup can be read and has every photo it lists, so an unchanged library needs no new write.
	public var isIntact: Bool {
		guard let current = try? readDocument(at: documentURL) else { return false }
		return isComplete(current.document)
	}

	/// The latest document alone, without checking its photos, such as for a list of backups; when it can't be read, the
	/// previous copy stands in. With `previous`, the previous copy only.
	public func document(previous: Bool = false) throws -> BackupDocument {
		if previous { return try readDocument(at: previousURL).document }
		do {
			return try readDocument(at: documentURL).document
		} catch {
			guard access.exists(previousURL), let earlier = try? readDocument(at: previousURL) else { throw error }
			return earlier.document
		}
	}

	/// The backup with every photo it lists, each checked against the SHA-256 its name records. A photo that is missing,
	/// damaged or can't be downloaded fails the whole load: a restore without it could never be repaired.
	///
	/// - Parameter stagingDirectory: Where to copy each checked photo, so a restore reads its own files whatever happens
	///   in the folder meanwhile, as for a folder in iCloud. Without it, the photos are checked where they lie.
	public func load(previous: Bool = false, stagingDirectory: URL? = nil) throws -> LoadedBackup {
		let document = try document(previous: previous)
		var files: [String: URL] = [:]
		for photo in document.photos where files[photo.file] == nil {
			let source = photosURL.appendingPathComponent(photo.file)
			guard access.exists(source) else { throw BackupError.photoUnavailable }
			let checked: URL
			do {
				checked = try access.reading(source) { url in
					guard let stagingDirectory else { return url }
					let staged = stagingDirectory.appendingPathComponent(photo.file)
					try? FileManager.default.removeItem(at: staged)
					try FileManager.default.copyItem(at: url, to: staged)
					return staged
				}
			} catch {
				throw BackupError.photoUnavailable
			}
			guard (try? ArchivedFile.digest(of: checked)) == BackupCodec.digest(inPhotoFile: photo.file) else {
				throw BackupError.photoUnavailable
			}
			files[photo.file] = checked
		}
		return LoadedBackup(document: document, photoFiles: files)
	}

	/// Whether iCloud holds the latest backup yet, its document and every photo it lists.
	public func uploadState() -> BackupUploadState {
		let listed = (try? readDocument(at: documentURL).document.photos.map(\.file)) ?? []
		let states = ([documentURL] + Set(listed).sorted().map { photosURL.appendingPathComponent($0) }).map(access.uploadState(of:))
		if states.contains(.notInICloud) { return .notInICloud }
		if states.contains(.failed) { return .failed }
		return states.contains(.uploading) ? .uploading : .uploaded
	}

	/// Whether every photo `document` lists is in the folder, each on the device with the bytes its name records.
	func isComplete(_ document: BackupDocument) -> Bool {
		document.photos.allSatisfy(holds)
	}

	/// Whether the folder has the file of `photo` with the right bytes. A file on the device must match the SHA-256 its
	/// name records, so a damaged one is never taken for a good copy; one iCloud has not downloaded yet can't be checked
	/// without downloading it, and counts as there.
	private func holds(_ photo: BackupPhoto) -> Bool {
		let file = photosURL.appendingPathComponent(photo.file)
		guard access.exists(file) else { return false }
		guard let size = access.localSize(of: file) else { return true }
		guard size == photo.size else { return false }
		let digest = try? access.reading(file) { try BackupDigestCache.shared.digest(of: $0) }
		return digest == BackupCodec.digest(inPhotoFile: photo.file)
	}

	private func readDocument(at url: URL) throws -> (data: Data, document: BackupDocument) {
		let data = try access.read(url, maximumSize: BackupCodec.maximumDocumentSize)
		return (data, try BackupCodec.decode(data))
	}
}
