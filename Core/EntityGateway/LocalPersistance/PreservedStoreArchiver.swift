import Foundation

/// Builds the archive a preserved store is exported as, in two steps: `stage` gathers its files into a folder (under
/// the store-load claim, so only quick links and copies happen there) and `compress` zips that folder.
///
/// The archive holds `Store/` with the SQLite files byte for byte, `Photos/`, `manifest.json` and `README.txt`.
struct PreservedStoreArchiver {
	let storeFileName: String

	/// The archive's folder and file name, such as `GrowingUp-earlier-data-2026-11-08`: the day the store was set aside.
	static func archiveName(for store: PreservedStore) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd"
		return "GrowingUp-earlier-data-\(formatter.string(from: store.preservedAt))"
	}

	/// Gathers `store`'s SQLite files from `folder` and `photos` into a new folder inside `directory`, and returns it.
	func stage(store: PreservedStore, folder: URL, photos: [URL], exportedAt: Date, in directory: URL) throws -> URL {
		let root = directory.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
			.appendingPathComponent(Self.archiveName(for: store), isDirectory: true)
		let storeFolder = root.appendingPathComponent("Store", isDirectory: true)
		let photosFolder = root.appendingPathComponent("Photos", isDirectory: true)
		do {
			try FileManager.default.createDirectory(at: storeFolder, withIntermediateDirectories: true)
			try FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
			var files: [ArchivedFile] = []
			for suffix in ["", "-wal", "-shm"] {
				let source = folder.appendingPathComponent(storeFileName + suffix)
				guard FileManager.default.fileExists(atPath: source.path) else { continue }
				// A copy, never a link: an archive must not share its database with the preserved one.
				let destination = storeFolder.appendingPathComponent(source.lastPathComponent)
				try FileManager.default.copyItem(at: source, to: destination)
				let copied = try ArchivedFile(at: destination, path: "Store/\(source.lastPathComponent)")
				guard try ArchivedFile.digest(of: source) == copied.sha256 else { throw CocoaError(.fileReadCorruptFile) }
				files.append(copied)
			}
			guard files.contains(where: { $0.path == "Store/\(storeFileName)" }) else { throw CocoaError(.fileNoSuchFile) }
			for source in photos.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
				let destination = photosFolder.appendingPathComponent(source.lastPathComponent)
				try FileManager.default.linkOrCopyItem(at: source, to: destination)
				files.append(try ArchivedFile(at: destination, path: "Photos/\(source.lastPathComponent)"))
			}
			let manifest = ArchiveManifest(
				preservedAt: store.preservedAt, exportedAt: exportedAt, cause: store.cause.reportedError.code,
				preservedByAppVersion: store.appVersion, exportedByAppVersion: PreservedStoreManifest.currentAppVersion, files: files)
			try PreservedStoreManifest.encoder.encode(manifest).write(to: root.appendingPathComponent("manifest.json"))
			try Data(Self.readme.utf8).write(to: root.appendingPathComponent("README.txt"))
			return root
		} catch {
			try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
			throw error
		}
	}

	/// Zips the staged folder `root` into `directory` and returns the archive. Foundation zips a folder that is read
	/// for uploading; the archive it makes lasts only for the read, so it is copied out first.
	func compress(_ root: URL, into directory: URL) throws -> URL {
		let destination = directory.appendingPathComponent(root.lastPathComponent).appendingPathExtension("zip")
		try? FileManager.default.removeItem(at: destination)
		var coordinationError: NSError?
		var copyError: Error?
		NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: root, options: .forUploading, error: &coordinationError) { zip in
			do {
				try FileManager.default.copyItem(at: zip, to: destination)
			} catch {
				copyError = error
			}
		}
		if let error = coordinationError ?? copyError {
			try? FileManager.default.removeItem(at: destination)
			throw error
		}
		return destination
	}

	static let readme = """
		GrowingUp preserved data

		This version of GrowingUp could not open the people and photos saved on this device by an earlier \
		version, so it set them aside unchanged instead of deleting them, and started a new, empty list.

		This archive is a complete copy of what was set aside:
		- Store/: the app's original database files, exactly as they were preserved.
		- Photos/: the photos those people had.
		- manifest.json: when the data was preserved and exported, and the size and SHA-256 checksum of every file.

		Keep this archive somewhere safe. A later version of GrowingUp may be able to open it again. If you contact \
		support about it, mention the dates in manifest.json; only send the archive itself if you choose to.

		---

		Сохранённые данные GrowingUp

		Эта версия GrowingUp не смогла открыть людей и фото, которые раньше сохранила на этом устройстве предыдущая \
		версия. Поэтому она отложила их без изменений, ничего не удалив, и начала новый, пустой список.

		В этом архиве полная копия отложенных данных:
		- Store/: исходные файлы базы приложения, ровно такие, какими они были сохранены.
		- Photos/: фото этих людей.
		- manifest.json: когда данные были отложены и выгружены, размер и контрольная сумма SHA-256 каждого файла.

		Сохраните архив в надёжном месте. Возможно, следующая версия GrowingUp снова сможет его открыть. Если будете \
		писать в поддержку, укажите даты из manifest.json; сам архив отправляйте, только если захотите.

		"""
}
