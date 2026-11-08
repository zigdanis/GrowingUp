import Foundation

/// One backup as a folder: `backup.json` with the `BackupDocument`, and `photos/` with each photo file it lists, named by
/// its SHA-256 (see `BackupCodec.photoFile(digest:name:)`). An exported archive holds the same layout.
public struct BackupFolder: Sendable {
	public static let documentName = "backup.json"
	public static let photosFolderName = "photos"

	public let url: URL

	public init(url: URL) {
		self.url = url
	}

	private var documentURL: URL { url.appendingPathComponent(Self.documentName) }
	private var photosURL: URL { url.appendingPathComponent(Self.photosFolderName, isDirectory: true) }

	/// Writes `snapshot`: the photos first and the document last, so the document never names a photo that is not there.
	/// A photo file already in the folder holds the same bytes, as its name says, and stays.
	public func write(_ snapshot: LibrarySnapshot) throws {
		try FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
		for photo in snapshot.document.photos {
			let destination = photosURL.appendingPathComponent(photo.file)
			guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
			guard let source = snapshot.photoSources[photo.file] else { throw CocoaError(.fileNoSuchFile) }
			try FileManager.default.copyItem(at: source, to: destination)
		}
		try BackupCodec.encode(snapshot.document).write(to: documentURL, options: .atomic)
	}

	/// The document alone, without checking its photos, such as for a list of backups.
	public func document() throws -> BackupDocument {
		let size = try documentURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
		guard size <= BackupCodec.maximumDocumentSize else { throw BackupError.notABackup }
		return try BackupCodec.decode(Data(contentsOf: documentURL))
	}

	/// The backup with every photo it lists, each checked against the SHA-256 its name records. A photo that is missing
	/// or damaged fails the whole load: a restore without it could never be repaired.
	public func load() throws -> LoadedBackup {
		let document = try document()
		var files: [String: URL] = [:]
		for photo in document.photos where files[photo.file] == nil {
			let file = photosURL.appendingPathComponent(photo.file)
			guard FileManager.default.fileExists(atPath: file.path),
				(try? ArchivedFile.digest(of: file)) == BackupCodec.digest(inPhotoFile: photo.file)
			else { throw BackupError.photoUnavailable }
			files[photo.file] = file
		}
		return LoadedBackup(document: document, photoFiles: files)
	}
}
