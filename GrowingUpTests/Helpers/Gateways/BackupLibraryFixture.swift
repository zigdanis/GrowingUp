import CoreData
import Foundation

@testable import Core

/// A library for backup tests: an in-memory store, a photos folder and a backup gateway over both, in a temporary folder
/// whose path has spaces like the App Group's `Application Support`.
final class BackupLibraryFixture {
	let root: URL
	let photos: URL
	let stack = InMemoryCoreDataStack()
	let gateway: CoreDataPeopleBackupGateway

	init() throws {
		root = FileManager.default.temporaryDirectory.appendingPathComponent("Backup Tests \(UUID().uuidString)", isDirectory: true)
		photos = root.appendingPathComponent("App Group", isDirectory: true)
		try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
		gateway = CoreDataPeopleBackupGateway(coreDataStack: stack, photosDirectory: photos)
	}

	func remove() throws {
		try FileManager.default.removeItem(at: root)
	}

	/// Stores a person directly, with the photo files `pictures` names written as `<id>.<extension>` holding `bytes`.
	@discardableResult
	func addPerson(
		name: String, birthday: Date = Date(timeIntervalSince1970: 1_600_000_000), order: Int64 = 0, onWidget: Bool = false,
		appPic: UUID? = nil, originalPic: UUID? = nil, files: [String: String] = [:], id: UUID = UUID()
	) throws -> UUID {
		// Its own context on its own queue: async tests don't run on the main thread that a view context needs.
		let context = stack.persistentContainer.newBackgroundContext()
		try context.performAndWait {
			guard let person = context.addEntity(withType: CoreDataPerson.self) else { throw CoreError.missingValue }
			person.id = id.uuidString
			person.name = name
			person.birthdate = birthday
			person.displayOrder = order
			person.appPicId = appPic?.uuidString
			person.widgetPicId = appPic?.uuidString
			person.originalPicId = originalPic?.uuidString
			person.appPicCrop = originalPic == nil ? nil : PhotoCrop(minX: 0.1, minY: 0.2, width: 0.5, height: 0.6).storedValue
			person.accessToWidget = onWidget ? try AccessToWidget.sharedInstance(in: context) : nil
			try context.save()
		}
		for (file, bytes) in files {
			try Data(bytes.utf8).write(to: photos.appendingPathComponent(file))
		}
		return id
	}

	func storedPeople() throws -> [Person] {
		let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
		request.sortDescriptors = CoreDataPersonsGateway.mosaicOrder
		let context = stack.persistentContainer.newBackgroundContext()
		return try context.performAndWait { try context.fetch(request).map(\.person) }
	}

	func photoFiles() throws -> [String] {
		try FileManager.default.contentsOfDirectory(atPath: photos.path).sorted()
	}

	func contents(of file: String) throws -> String {
		String(bytes: try Data(contentsOf: photos.appendingPathComponent(file)), encoding: .utf8) ?? ""
	}

	/// Writes `snapshot` into a backup folder under the fixture and reads it back, as a restore would.
	func roundTrip(_ snapshot: LibrarySnapshot) throws -> LoadedBackup {
		let folder = BackupFolder(url: root.appendingPathComponent("Backup \(UUID().uuidString)", isDirectory: true))
		try folder.write(snapshot)
		return try folder.load()
	}
}
