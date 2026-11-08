import Core
import Foundation
import ZIPFoundation

/// The file "Export all data" writes and "Import from file" reads: one zip with a `BackupFolder` inside (`backup.json`
/// and `photos/`) and a README, so it opens in Files as plain JSON and images. Everything happens in a folder of the
/// app's temporary files: each export replaces the one before, and each import the one before.
struct BackupArchive: Sendable {
	static let readmeName = "README.txt"

	let directory: URL
	/// The most a backup may unpack to: far beyond 20 people with three photos each, so a larger one is not one the app
	/// wrote.
	var maximumSize: UInt64 = 2 << 30

	static let temporary = BackupArchive(
		directory: FileManager.default.temporaryDirectory.appendingPathComponent("BackupArchives", isDirectory: true))

	private var exportsDirectory: URL { directory.appendingPathComponent("Export", isDirectory: true) }
	private var importsDirectory: URL { directory.appendingPathComponent("Import", isDirectory: true) }

	/// Writes `snapshot` as `GrowingUp-backup-<date>.zip` and returns it; the export before it goes.
	func export(_ snapshot: LibrarySnapshot) throws -> URL {
		try reset(exportsDirectory)
		let url = exportsDirectory.appendingPathComponent(Self.fileName(for: snapshot.document.createdAt))
		do {
			let archive = try Archive(url: url, accessMode: .create)
			try add(BackupCodec.encode(snapshot.document), as: BackupFolder.documentName, to: archive)
			var added = Set<String>()
			for photo in snapshot.document.photos where added.insert(photo.file).inserted {
				guard let source = snapshot.photoSources[photo.file] else { throw CocoaError(.fileNoSuchFile) }
				// Photos are compressed already; storing them keeps the export quick.
				try archive.addEntry(with: BackupFolder.photosFolderName + "/" + photo.file, fileURL: source, compressionMethod: .none)
			}
			try add(Data(Self.readme.utf8), as: Self.readmeName, to: archive)
		} catch {
			try? FileManager.default.removeItem(at: url)
			throw error
		}
		return url
	}

	/// Unpacks the backup in the zip at `url` into a new folder and reads it. Only `backup.json` and photo files named as
	/// a backup names them are taken, at the top or inside one folder (as when the person zipped the unpacked folder
	/// again); anything else in the zip is ignored.
	func open(_ url: URL) throws -> LoadedBackup {
		try reset(importsDirectory)
		let folder = importsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let archive: Archive
		do {
			archive = try Archive(url: url, accessMode: .read)
		} catch {
			throw BackupError.notABackup
		}
		let entries = Array(archive).filter { $0.type == .file }
		guard let document = entries.first(where: { Self.relativePath(of: $0.path) == BackupFolder.documentName }),
			document.uncompressedSize <= UInt64(BackupCodec.maximumDocumentSize)
		else { throw BackupError.notABackup }
		let prefix = String(document.path.dropLast(BackupFolder.documentName.count))
		let taken = entries.filter { entry in
			guard entry.path.hasPrefix(prefix), let relative = Self.relativePath(of: entry.path) else { return false }
			return String(entry.path.dropFirst(prefix.count)) == relative
		}
		// The sizes a zip declares can lie: what is written is counted as it is unpacked.
		var total: UInt64 = 0
		for entry in taken {
			guard let relative = Self.relativePath(of: entry.path) else { continue }
			// Every entry, the document too, fits in what is left, so the total never passes the limit.
			let remaining = maximumSize - total
			let limit = relative == BackupFolder.documentName ? min(UInt64(BackupCodec.maximumDocumentSize), remaining) : remaining
			total += try extract(entry, from: archive, to: folder.appendingPathComponent(relative), limit: limit)
		}
		return try BackupFolder(url: folder).load()
	}

	/// Unpacks `entry` into a new file at `destination`, failing as soon as it grows beyond `limit` bytes, and returns
	/// its size.
	private func extract(_ entry: Entry, from archive: Archive, to destination: URL, limit: UInt64) throws -> UInt64 {
		guard entry.uncompressedSize <= limit else { throw BackupError.notABackup }
		try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data().write(to: destination, options: .withoutOverwriting)
		let handle = try FileHandle(forWritingTo: destination)
		defer { try? handle.close() }
		var written: UInt64 = 0
		_ = try archive.extract(entry) { chunk in
			written += UInt64(chunk.count)
			guard written <= limit else { throw BackupError.notABackup }
			try handle.write(contentsOf: chunk)
		}
		return written
	}

	/// Reads a file the person picked, as from Files or iCloud Drive: with the access the picker granted, and through
	/// file coordination, which downloads a file that is only in iCloud first.
	func openPicked(_ url: URL) throws -> LoadedBackup {
		let isScoped = url.startAccessingSecurityScopedResource()
		defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
		var coordinationError: NSError?
		var result: Result<LoadedBackup, Error> = .failure(BackupError.notABackup)
		NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
			result = Result { try open(url) }
		}
		if let coordinationError { throw coordinationError }
		return try result.get()
	}

	/// Removes every file an export or import left, as when its sheet closes.
	func removeAll() {
		try? FileManager.default.removeItem(at: directory)
	}

	/// Removes the file the last export wrote, as when the share sheet closes.
	func removeExports() {
		try? FileManager.default.removeItem(at: exportsDirectory)
	}

	/// Removes what imports unpacked, once a restore no longer needs it.
	func removeImports() {
		try? FileManager.default.removeItem(at: importsDirectory)
	}

	/// `backup.json` or `photos/<sha256>.<ext>` for an entry at the top of the zip or in one folder, else nil.
	static func relativePath(of path: String) -> String? {
		var components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
		if components.count == 3 || (components.count == 2 && components[1] == BackupFolder.documentName) {
			components.removeFirst()
		}
		switch components.count {
		case 1 where components[0] == BackupFolder.documentName:
			return BackupFolder.documentName
		case 2 where components[0] == BackupFolder.photosFolderName && BackupCodec.isPhotoFile(components[1]):
			return components.joined(separator: "/")
		default:
			return nil
		}
	}

	static func fileName(for date: Date) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd-HHmm"
		return "GrowingUp-backup-\(formatter.string(from: date)).zip"
	}

	private func reset(_ folder: URL) throws {
		try? FileManager.default.removeItem(at: folder)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
	}

	private func add(_ data: Data, as path: String, to archive: Archive) throws {
		try archive.addEntry(
			with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate,
			provider: { position, size in data.subdata(in: Int(position)..<Int(position) + size) })
	}

	static let readme = """
		GrowingUp backup

		A copy of everyone in GrowingUp on the day it was made, with their photos. To bring them back, open \
		GrowingUp, tap the gear at the top of the home screen to open Settings, then Import from file, and pick this file. \
		Import only adds people who are missing; it never changes or deletes anyone.

		- backup.json: each person's name, birthday and settings, and which photo files belong to them.
		- photos/: the photos, each named by its SHA-256 checksum.

		Keep this file somewhere safe: it holds names, birthdays and photos of the people you added.

		---

		Резервная копия GrowingUp

		Копия всех людей из GrowingUp на день её создания, вместе с фото. Чтобы вернуть их, откройте GrowingUp, \
		нажмите шестерёнку вверху главного экрана, чтобы открыть «Настройки», затем «Импортировать из файла» и выберите \
		этот файл. Импорт \
		только добавляет недостающих людей и никого не меняет и не удаляет.

		- backup.json: имя, день рождения и настройки каждого человека и то, какие файлы фото к нему относятся.
		- photos/: фото, каждое названо по своей контрольной сумме SHA-256.

		Храните файл в надёжном месте: в нём имена, дни рождения и фото добавленных вами людей.

		"""
}
