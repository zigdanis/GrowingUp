import CoreData
import Foundation

/// The library as the Core Data store and the photo files hold it: read whole for a backup, and added to from one.
///
/// A restore only ever adds: a person of the backup whose identifier, or whose name and day of birth, the library already
/// has stays out, and so does anyone beyond `Constants.peopleLimit`. Their photos are written under new names first, so
/// no file of the library is ever replaced, and the people are saved together; a failure saves nobody and removes the
/// photo files it wrote, and only those.
public final class CoreDataPeopleBackupGateway: PeopleBackupGateway, @unchecked Sendable {
	private static let photoExtensions = ["png", "heic", "jpg"]

	private let coreDataStack: CoreDataStack
	/// Where the app keeps every person's photo files, as `<UUID>.png`, `.jpg` or `.heic`; see `DiskImageStore`.
	private let photosDirectory: URL
	private let digestLock = NSLock()
	/// The SHA-256 of each photo file already read, by its path, size and modification date: a backup reads every photo,
	/// and the files of a picture never change once written.
	private var digests: [String: String] = [:]

	public init(coreDataStack: CoreDataStack, photosDirectory: URL) {
		self.coreDataStack = coreDataStack
		self.photosDirectory = photosDirectory
	}

	/// The App Group's store and photos, as the app and the widget use them.
	public static func shared() throws -> CoreDataPeopleBackupGateway {
		CoreDataPeopleBackupGateway(
			coreDataStack: CoreDataStackImplementation.sharedInstance, photosDirectory: try CoreDataStackImplementation.appGroupDirectory())
	}

	public func snapshot(createdAt: Date, appVersion: String, deviceModel: String) async throws -> LibrarySnapshot {
		let people = try await fetchPeople().map(BackupPerson.init)
		var photos: [BackupPhoto] = []
		var sources: [String: URL] = [:]
		var stored = Set<UUID>()
		var seen = Set<UUID>()
		for id in people.flatMap(\.pictureIds) where seen.insert(id).inserted {
			// A picture may lie in more than one format, such as an original kept as HEIC and as the PNG it was before.
			for fileExtension in Self.photoExtensions {
				let name = id.uuidString + "." + fileExtension
				let url = photosDirectory.appendingPathComponent(name)
				guard let (size, digest) = try fingerprint(of: url) else { continue }
				let file = BackupCodec.photoFile(digest: digest, name: name)
				photos.append(BackupPhoto(name: name, file: file, size: size))
				sources[file] = url
				stored.insert(id)
			}
		}
		// A picture whose file is gone already shows nothing here; the backup says so instead of naming a missing photo.
		let document = BackupDocument(
			createdAt: createdAt, appVersion: appVersion, deviceModel: deviceModel,
			people: people.map { $0.keepingPictures(stored) }, photos: photos)
		return LibrarySnapshot(document: document, photoSources: sources)
	}

	public func restore(_ backup: LoadedBackup) async throws -> RestoreSummary {
		try Task.checkCancellation()
		let container = try coreDataStack.persistentContainer
		return try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
				CoreDataPersonsGateway.orderLock.lock()
				defer { CoreDataPersonsGateway.orderLock.unlock() }
				var written: [URL] = []
				do {
					let summary = try self.restore(backup, in: context, written: &written)
					continuation.resume(returning: summary)
				} catch {
					context.rollback()
					for url in written { try? FileManager.default.removeItem(at: url) }
					continuation.resume(throwing: error as? BackupError ?? CoreError(error: error))
				}
			}
		}
	}

	private func restore(_ backup: LoadedBackup, in context: NSManagedObjectContext, written: inout [URL]) throws -> RestoreSummary {
		let stored = try context.fetch(CoreDataPerson.fetchRequest()).map(\.person)
		var ids = Set(stored.map(\.id))
		var keys = Set(stored.map { Self.matchKey(name: $0.name, birthday: $0.birthday) })
		var count = stored.count
		var pinned = stored.filter(\.isOnWidget).count
		var order = try CoreDataPersonsGateway.lastDisplayOrder(in: context)
		var summary = RestoreSummary(peopleAdded: 0, peopleAlreadyPresent: 0, peopleOverLimit: 0, intoEmptyLibrary: stored.isEmpty)
		let photosByPicture = Dictionary(grouping: backup.document.photos) { PhotoFileName.id(of: $0.name) }
		let people = backup.document.people.sorted { ($0.displayOrder, $0.createdDate) < ($1.displayOrder, $1.createdDate) }
		for person in people {
			let key = Self.matchKey(name: person.name, birthday: person.birthday)
			guard !ids.contains(person.id), !keys.contains(key) else {
				summary.peopleAlreadyPresent += 1
				continue
			}
			guard count < Constants.peopleLimit else {
				summary.peopleOverLimit += 1
				continue
			}
			let pictures = try writePictures(of: person, from: backup, photos: photosByPicture, written: &written)
			guard let record = context.addEntity(withType: CoreDataPerson.self) else { throw CoreError.coreDataAddFailed }
			order += 1
			Self.populate(record, with: person, pictures: pictures, order: order)
			if person.isOnWidget, pinned < Constants.widgetPeopleLimit {
				record.accessToWidget = try AccessToWidget.sharedInstance(in: context)
				pinned += 1
			}
			ids.insert(person.id)
			keys.insert(key)
			count += 1
			summary.peopleAdded += 1
		}
		if context.hasChanges { try context.save() }
		return summary
	}

	/// Writes the photo files of `person`'s pictures under new names, so a file the library has is never replaced, and
	/// returns each picture's new identifier. A picture without files in the backup gets none.
	private func writePictures(
		of person: BackupPerson, from backup: LoadedBackup, photos: [UUID?: [BackupPhoto]], written: inout [URL]
	) throws -> [UUID: UUID] {
		var pictures: [UUID: UUID] = [:]
		for picture in person.pictureIds {
			guard let files = photos[picture], !files.isEmpty else { throw BackupError.photoUnavailable }
			let renamed = UUID()
			for photo in files {
				guard let source = backup.photoFiles[photo.file] else { throw BackupError.photoUnavailable }
				let fileExtension = URL(fileURLWithPath: photo.name).pathExtension.lowercased()
				let destination = photosDirectory.appendingPathComponent(renamed.uuidString + "." + fileExtension)
				// A new file rather than a copy, so it takes the App Group's protection, which lets the widget read it
				// while the device is locked. It is the restore's own from the moment it exists.
				try Data().write(to: destination, options: [.withoutOverwriting])
				written.append(destination)
				try Self.copyContents(of: source, to: destination)
			}
			pictures[picture] = renamed
		}
		return pictures
	}

	/// Copies the bytes of `source` into the existing file `destination` a megabyte at a time, so a large photo never
	/// sits in memory whole.
	private static func copyContents(of source: URL, to destination: URL) throws {
		let input = try FileHandle(forReadingFrom: source)
		defer { try? input.close() }
		let output = try FileHandle(forWritingTo: destination)
		defer { try? output.close() }
		while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
			try output.write(contentsOf: chunk)
		}
	}

	/// Fills a new record with `person` as the backup holds them, their pictures under their new identifiers.
	private static func populate(_ record: CoreDataPerson, with person: BackupPerson, pictures: [UUID: UUID], order: Int64) {
		record.id = person.id.uuidString
		record.name = person.name
		record.birthdate = person.birthday
		record.createdDate = person.createdDate
		record.celebratesBirthdays = person.celebratesBirthdays
		record.appPicId = person.appPicId.flatMap { pictures[$0] }?.uuidString
		record.widgetPicId = person.widgetPicId.flatMap { pictures[$0] }?.uuidString
		record.originalPicId = person.originalPicId.flatMap { pictures[$0] }?.uuidString
		record.appPicCrop = record.appPicId == nil ? nil : person.appPicCrop?.storedValue
		record.widgetPicCrop = record.widgetPicId == nil ? nil : person.widgetPicCrop?.storedValue
		record.displayOrder = order
	}

	private func fetchPeople() async throws -> [Person] {
		try Task.checkCancellation()
		let container = try coreDataStack.persistentContainer
		return try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
				let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
				request.sortDescriptors = CoreDataPersonsGateway.mosaicOrder
				do {
					continuation.resume(returning: try context.fetch(request).map(\.person))
				} catch {
					continuation.resume(throwing: CoreError(error: error))
				}
			}
		}
	}

	/// The size and SHA-256 of the file at `url`, or nil when there is none.
	private func fingerprint(of url: URL) throws -> (size: Int, digest: String)? {
		let values: URLResourceValues
		do {
			values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
		} catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
			return nil
		}
		guard values.isRegularFile == true else { return nil }
		let size = values.fileSize ?? 0
		let key = "\(url.path)|\(size)|\((values.contentModificationDate ?? .distantPast).timeIntervalSinceReferenceDate)"
		digestLock.lock()
		let known = digests[key]
		digestLock.unlock()
		if let known { return (size, known) }
		let digest = try ArchivedFile.digest(of: url)
		digestLock.lock()
		digests[key] = digest
		digestLock.unlock()
		return (size, digest)
	}

	/// What makes two people the same when their identifiers differ, as when someone was added again by hand after a
	/// reinstall: the same name, ignoring case and surrounding spaces, and the same day of birth.
	static func matchKey(name: String, birthday: Date) -> String {
		let day = Calendar.current.dateComponents([.year, .month, .day], from: birthday)
		let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		return "\(normalized)|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
	}
}
